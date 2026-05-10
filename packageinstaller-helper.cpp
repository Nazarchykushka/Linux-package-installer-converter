#include <iostream>
#include <fstream>
#include <string>
#include <filesystem>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <sys/wait.h>
#include <cmath>
#include <flatpak/flatpak.h>
#include <glib.h>
#include <fcntl.h>

namespace fs = std::filesystem;

// ─────────────────────────────────────────────
//  Utility: run command and broadcast output
// ─────────────────────────────────────────────
static int runCommand(const std::string &cmd)
{
    std::cout << "[helper] Running: " << cmd << std::endl;
    std::cout.flush();
    int ret = system(cmd.c_str());
    return WEXITSTATUS(ret);
}

// ─────────────────────────────────────────────
//  install-pkg  <pkg_path>
// ─────────────────────────────────────────────
static int cmdInstallPkg(const std::string &pkgPath)
{
    std::cout << "Installing package: " << pkgPath << std::endl;
    std::cout.flush();
    int code = runCommand("pacman -U --noconfirm --overwrite \"*\" \"" + pkgPath + "\"");
    if (code != 0) {
        std::cerr << "pacman -U failed with code " << code << std::endl;
        return code;
    }
    return 0;
}

// ─────────────────────────────────────────────
//  remove-pkg  <pkg_name>
// ─────────────────────────────────────────────
static int cmdRemovePkg(const std::string &pkgName)
{
    std::cout << "Removing package: " << pkgName << std::endl;
    std::cout.flush();
    int code = runCommand("pacman -Rns --noconfirm \"" + pkgName + "\"");
    if (code != 0) {
        std::cerr << "pacman -Rns failed with code " << code << std::endl;
        return code;
    }
    return 0;
}

// ─────────────────────────────────────────────
//  kill-pacman
// ─────────────────────────────────────────────
static int cmdKillPacman()
{
    std::cout << "Killing pacman and flatpak processes..." << std::endl;
    std::cout.flush();
    runCommand("pkill -9 pacman");
    runCommand("pkill -9 -f 'packageinstaller-helper install-flatpak'");
    runCommand("pkill -9 -f 'packageinstaller-helper install-pkg'");
    runCommand("rm -f /var/lib/pacman/db.lck");
    return 0;
}
// ─────────────────────────────────────────────
//  install-app
// ─────────────────────────────────────────────
static int cmdInstallApp(const std::string &appName,
                         const std::string &srcDir,
                         const std::string &execFilename,
                         const std::string &iconFilename)
{
    std::string targetDir = "/opt/" + appName;
    std::cout << "Copying " << srcDir << " -> " << targetDir << std::endl;
    std::cout.flush();

    try {
        if (fs::exists(targetDir))
            fs::remove_all(targetDir);
        fs::copy(srcDir, targetDir,
                 fs::copy_options::recursive | fs::copy_options::overwrite_existing);
        fs::remove_all(srcDir);
    } catch (const fs::filesystem_error &e) {
        std::cerr << "Copy failed: " << e.what() << std::endl;
        return 1;
    }

    std::string userHome;
    const char *pkexecUid = getenv("PKEXEC_UID");
    if (pkexecUid) {
        std::ifstream passwd("/etc/passwd");
        std::string line;
        std::string uid(pkexecUid);
        while (std::getline(passwd, line)) {
            size_t p1 = line.find(':');
            size_t p2 = line.find(':', p1+1);
            size_t p3 = line.find(':', p2+1);
            size_t p4 = line.find(':', p3+1);
            size_t p5 = line.find(':', p4+1);
            size_t p6 = line.find(':', p5+1);
            if (p1==std::string::npos || p2==std::string::npos ||
                p3==std::string::npos || p6==std::string::npos) continue;
            std::string lineUid = line.substr(p2+1, p3-p2-1);
            if (lineUid == uid) {
                userHome = line.substr(p5+1, p6-p5-1);
                break;
            }
        }
    }
    if (userHome.empty()) {
        const char *home = getenv("HOME");
        userHome = home ? home : "/root";
    }

    std::string cacheDir        = userHome + "/.cache/PackageInstaller";
    std::string cacheDesktopPath = cacheDir + "/" + appName + ".desktop";
    std::string finalDesktopPath = "/usr/share/applications/" + appName + ".desktop";

    try { fs::create_directories(cacheDir); } catch (...) {}

    {
        std::ofstream f(cacheDesktopPath);
        if (!f.is_open()) {
            std::cerr << "Cannot create desktop file: " << cacheDesktopPath << std::endl;
            return 1;
        }
        f << "[Desktop Entry]\n"
          << "Name="    << appName       << "\n"
          << "Exec=/opt/" << appName << "/" << execFilename << "\n"
          << "Type=Application\n"
          << "Icon=/opt/" << appName
          << "/browser/chrome/icons/default/" << iconFilename << "\n"
          << "Categories=Utility;Application;\n";
    }

    try {
        fs::copy_file(cacheDesktopPath, finalDesktopPath,
                      fs::copy_options::overwrite_existing);
        fs::remove(cacheDesktopPath);
    } catch (const fs::filesystem_error &e) {
        std::cerr << "Failed to move .desktop: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}

// ─────────────────────────────────────────────
//  install-pkg-byname
// ─────────────────────────────────────────────
static int cmdInstallPkgByName(const std::string &pkgName)
{
    std::cout << "Installing package by name: " << pkgName << std::endl;
    std::cout.flush();
    int code = runCommand("pacman -S --noconfirm \"" + pkgName + "\"");
    if (code != 0) {
        std::cerr << "pacman -S failed with code " << code << std::endl;
        return code;
    }
    return 0;
}

// ═════════════════════════════════════════════
//  FLATPAK — directly via libflatpak
// ═════════════════════════════════════════════

struct ProgressData {
    double      completedBytes    = 0.0;
    double      totalBytes        = 0.0;
    double      currentOpBytes    = 0.0;
    int         opIndex           = 0;
    int         opTotal           = 0;
    std::string home;
};
// Callback: progress changed

static void onProgressChanged(FlatpakTransactionProgress *progress, gpointer userData)
{
    auto *pd = static_cast<ProgressData *>(userData);
    guint64 bytes = flatpak_transaction_progress_get_bytes_transferred(progress);
    pd->currentOpBytes = static_cast<double>(bytes);

    double downloaded = pd->completedBytes + pd->currentOpBytes;
    double total      = pd->totalBytes > 1.0 ? pd->totalBytes : 1.0;

    int pct = static_cast<int>((downloaded / total) * 100.0);
    if (pct > 99) pct = 99;

    double dlMB    = downloaded / (1024.0 * 1024.0);
    double totalMB = total      / (1024.0 * 1024.0);

    if (pct == 99) {
        pct = 100;
        std::cout << "[installing]";
        std::cout.flush();
        return;
    }

    std::cout << "[progress] " << dlMB
              << " / " << totalMB
              << " MB (" << pct << "%) ["
              << pd->opIndex << "/" << pd->opTotal << "]"
              << std::endl;
    std::cout.flush();
}

static void onReady(FlatpakTransaction *tx, gpointer userData)
{
    auto *pd = static_cast<ProgressData *>(userData);
    pd->totalBytes = 0.0;
    pd->opTotal    = 0;

    GList *ops = flatpak_transaction_get_operations(tx);
    for (GList *l = ops; l != nullptr; l = l->next) {
        auto *op = static_cast<FlatpakTransactionOperation *>(l->data);
        guint64 size = flatpak_transaction_operation_get_download_size(op);
        pd->totalBytes += static_cast<double>(size);
        pd->opTotal++;
    }
    g_list_free(ops);

    std::cout << "Total download size: "
              << pd->totalBytes / (1024.0 * 1024.0)
              << " MB, operations: " << pd->opTotal << std::endl;
    std::cout.flush();
}

static void onNewOperation(FlatpakTransaction          *transaction,
                           FlatpakTransactionOperation *operation,
                           FlatpakTransactionProgress  *progress,
                           gpointer                     userData)
{
    (void)transaction; (void)operation;
    auto *pd = static_cast<ProgressData *>(userData);
    pd->opIndex++;
    pd->currentOpBytes = 0.0;
    flatpak_transaction_progress_set_update_frequency(progress, 300);
    g_signal_connect(progress, "changed", G_CALLBACK(onProgressChanged), pd);
}

static int runFlatpakTransaction(FlatpakTransaction *transaction, ProgressData *pd)
{
    g_signal_connect(transaction, "ready",         G_CALLBACK(onReady),        pd);
    g_signal_connect(transaction, "new-operation", G_CALLBACK(onNewOperation), pd);

    // Silence stderr (lseek errors, bsdtar warnings)
    int devNull     = open("/dev/null", O_WRONLY);
    int savedStderr = dup(STDERR_FILENO);
    if (devNull >= 0) {
        dup2(devNull, STDERR_FILENO);
        close(devNull);
    }

    GError   *error = nullptr;
    gboolean  ok    = flatpak_transaction_run(transaction, nullptr, &error);

    if (savedStderr >= 0) {
        dup2(savedStderr, STDERR_FILENO);
        close(savedStderr);
    }

    if (!ok) {
        std::cerr << "Flatpak error: "
                  << (error ? error->message : "unknown error") << std::endl;
        if (error) g_error_free(error);
        return 1;
    }
    return 0;
}

// ─────────────────────────────────────────────
//  install-flatpak  <flatpakref_path>
// ─────────────────────────────────────────────
static int cmdInstallFlatpak(const std::string &flatpakrefPath)
{

    std::cout << "Installing Flatpak from: " << flatpakrefPath << std::endl;
    std::cout.flush();

    GError *error = nullptr;

    FlatpakInstallation *inst = flatpak_installation_new_system(nullptr, &error);
    if (!inst) {
        if (error) g_error_free(error);
        error = nullptr;
        inst  = flatpak_installation_new_user(nullptr, &error);
    }
    if (!inst) {
        std::cerr << "Cannot open installation: " << error->message << std::endl;
        g_error_free(error);
        return 1;
    }

    FlatpakTransaction *tx =
        flatpak_transaction_new_for_installation(inst, nullptr, &error);
    if (!tx) {
        std::cerr << "Cannot create transaction: " << error->message << std::endl;
        g_error_free(error);
        g_object_unref(inst);
        return 1;
    }

    flatpak_transaction_set_no_pull(tx, FALSE);
    flatpak_transaction_set_no_deploy(tx, FALSE);

    gchar *contents = nullptr;
    gsize  length   = 0;
    if (!g_file_get_contents(flatpakrefPath.c_str(),
                             &contents, &length, &error)) {
        std::cerr << "Cannot read ref file: " << error->message << std::endl;
        g_error_free(error);
        g_object_unref(tx);
        g_object_unref(inst);
        return 1;
    }

    GBytes  *refData = g_bytes_new_take(contents, length);
    gboolean ok      = flatpak_transaction_add_install_flatpakref(tx,
                                                             refData,
                                                             &error);
    g_bytes_unref(refData);

    if (!ok) {
        std::cerr << "Add install failed: " << error->message << std::endl;
        g_error_free(error);
        g_object_unref(tx);
        g_object_unref(inst);
        return 1;
    }

    ProgressData pd;
    const char *homeEnv = getenv("HOME");
    pd.home = homeEnv ? homeEnv : "/root";
    std::remove((pd.home + "/.cache/flatpak_installing").c_str());

    int ret = runFlatpakTransaction(tx, &pd);

    g_object_unref(tx);
    g_object_unref(inst);
    return ret;
}

// ─────────────────────────────────────────────
//  install-flatpak-bundle  <bundle_path>
// ─────────────────────────────────────────────
static int cmdInstallFlatpakBundle(const std::string &bundlePath)
{
    std::cout << "Installing Flatpak bundle from: " << bundlePath << std::endl;
    std::cout.flush();

    GError *error = nullptr;

    // ── Try system first, then user ───────────────────────────────
    FlatpakInstallation *inst = flatpak_installation_new_system(nullptr, &error);
    if (!inst) {
        if (error) g_error_free(error);
        error = nullptr;
        inst  = flatpak_installation_new_user(nullptr, &error);
    }
    if (!inst) {
        std::cerr << "Cannot open installation: " << error->message << std::endl;
        g_error_free(error);
        return 1;
    }

    // ── Check if flathub is in repositories ─────────────────────────────
    // If not, add automatically
    {
        GPtrArray *remotes = flatpak_installation_list_remotes(inst, nullptr, nullptr);
        bool hasFlathub = false;
        if (remotes) {
            for (guint i = 0; i < remotes->len; i++) {
                auto *remote = static_cast<FlatpakRemote *>(g_ptr_array_index(remotes, i));
                const char *name = flatpak_remote_get_name(remote);
                if (name && std::string(name) == "flathub") {
                    hasFlathub = true;
                    break;
                }
            }
            g_ptr_array_unref(remotes);
        }

        if (!hasFlathub) {
            std::cout << "Adding Flathub remote..." << std::endl;
            std::cout.flush();

            // Read .flatpakrepo as GBytes
            const char *flathubRepoUrl = "https://flathub.org/repo/flathub.flatpakrepo";

            // Download via curl to temporary file
            std::string tmpFile = "/tmp/flathub.flatpakrepo";
            std::string curlCmd = std::string("curl -L -s -o ") + tmpFile
                                  + " " + flathubRepoUrl;
            int curlRet = system(curlCmd.c_str());

            if (curlRet == 0) {
                gchar *contents = nullptr;
                gsize  length   = 0;

                if (g_file_get_contents(tmpFile.c_str(), &contents, &length, &error)) {
                    GBytes *repoData = g_bytes_new_take(contents, length);

                    FlatpakRemote *remote = flatpak_remote_new_from_file(
                        "flathub", repoData, &error);
                    g_bytes_unref(repoData);

                    if (remote) {
                        flatpak_installation_add_remote(inst, remote, false,
                                                        nullptr, &error);
                        g_object_unref(remote);
                        if (error) {
                            std::cerr << "Warning: could not add flathub: "
                                      << error->message << std::endl;
                            g_error_free(error);
                            error = nullptr;
                        } else {
                            std::cout << "Flathub added successfully" << std::endl;
                            std::cout.flush();
                        }
                    } else {
                        if (error) { g_error_free(error); error = nullptr; }
                    }
                } else {
                    if (error) { g_error_free(error); error = nullptr; }
                }

                std::remove(tmpFile.c_str());
            } else {
                std::cerr << "Warning: could not download flathub repo file" << std::endl;
            }
        }
    }

    FlatpakTransaction *tx =
        flatpak_transaction_new_for_installation(inst, nullptr, &error);
    if (!tx) {
        std::cerr << "Cannot create transaction: " << error->message << std::endl;
        g_error_free(error);
        g_object_unref(inst);
        return 1;
    }

    // ── Allow transactions to download dependencies from remotes ────────────
    flatpak_transaction_set_no_pull(tx, FALSE);
    flatpak_transaction_set_no_deploy(tx, FALSE);

    GFile   *file = g_file_new_for_path(bundlePath.c_str());
    gboolean ok   = flatpak_transaction_add_install_bundle(tx, file,
                                                         nullptr, &error);
    g_object_unref(file);

    if (!ok) {
        std::cerr << "Add bundle failed: " << error->message << std::endl;
        g_error_free(error);
        g_object_unref(tx);
        g_object_unref(inst);
        return 1;
    }

    ProgressData pd;
    const char *homeEnv = getenv("HOME");
    pd.home = homeEnv ? homeEnv : "/root";
    std::remove((pd.home + "/.cache/flatpak_installing").c_str());

    int ret = runFlatpakTransaction(tx, &pd);

    g_object_unref(tx);
    g_object_unref(inst);
    return ret;
}

// ─────────────────────────────────────────────
//  main
// ─────────────────────────────────────────────
int main(int argc, char *argv[])
{
    if (argc < 2) {
        std::cerr << "Usage: packageinstaller-helper <command> [args...]\n"
                  << "Commands: install-pkg, remove-pkg, kill-pacman,\n"
                  << "          install-app, install-pkg-byname,\n"
                  << "          install-flatpak, install-flatpak-bundle\n";
        return 1;
    }

    std::string command = argv[1];

    if (command == "install-pkg") {
        if (argc < 3) { std::cerr << "install-pkg requires <pkg_path>\n"; return 1; }
        return cmdInstallPkg(argv[2]);
    }
    if (command == "remove-pkg") {
        if (argc < 3) { std::cerr << "remove-pkg requires <pkg_name>\n"; return 1; }
        return cmdRemovePkg(argv[2]);
    }
    if (command == "kill-pacman") {
        return cmdKillPacman();
    }
    if (command == "install-app") {
        if (argc < 6) {
            std::cerr << "install-app requires <app_name> <src_dir> "
                         "<exec_filename> <icon_filename>\n";
            return 1;
        }
        return cmdInstallApp(argv[2], argv[3], argv[4], argv[5]);
    }
    if (command == "install-pkg-byname") {
        if (argc < 3) { std::cerr << "install-pkg-byname requires <pkg_name>\n"; return 1; }
        return cmdInstallPkgByName(argv[2]);
    }
    if (command == "install-flatpak") {
        if (argc < 3) { std::cerr << "install-flatpak requires <flatpakref_path>\n"; return 1; }
        return cmdInstallFlatpak(argv[2]);
    }
    if (command == "install-flatpak-bundle") {
        if (argc < 3) { std::cerr << "install-flatpak-bundle requires <bundle_path>\n"; return 1; }
        return cmdInstallFlatpakBundle(argv[2]);
    }

    std::cerr << "Unknown command: " << command << "\n";
    return 1;
}