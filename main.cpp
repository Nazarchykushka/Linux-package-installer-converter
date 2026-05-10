#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QObject>
#include <QDebug>
#include <QProcess>
#include <archive.h>
#include <archive_entry.h>
#include <string>
#include <filesystem>
#include <vector>
#include <sys/stat.h>
#include <algorithm>
#include <QFileInfo>
#include <QRegularExpression>
#include <QDesktopServices>
#include <QUrl>
#include <filesystem>
#include <QStandardPaths>
#include <QDir>
#include <QDirIterator>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariant>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <QTimer>
#include <QTranslator>
#include <QFileSystemWatcher>
#include <QtConcurrent/QtConcurrent>
#include <QFutureWatcher>
#include <pty.h>
#include <termios.h>
#include <fcntl.h>
#include <QSocketNotifier>
#include <sys/wait.h>
#include <QIcon>
#include <QClipboard>
#include <chrono>
#include <fstream>
#include <QMenu>
#include <QSystemTrayIcon>
#include <QWindow>
#include <QLocalServer>
#include <QLocalSocket>
#include <QStyleHints>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlComponent>

static QLocalServer *g_localServer = nullptr;
const QString kSocketName = "PackageInstallerSocket";

// Function to show the window
static void showMainWindow(QQmlApplicationEngine *engine) {
    if (!engine) return;
    const auto roots = engine->rootObjects();
    if (!roots.isEmpty()) {
        if (auto *win = qobject_cast<QWindow*>(roots.first())) {
            win->show(); win->raise(); win->requestActivate();
        }
    }
}

extern QTranslator *g_translator;

using namespace std;

// Helper function for loading translation
static bool loadTranslator(QTranslator *translator, const QString &langCode) {
    if (langCode.isEmpty()) return false;

    // 1. Try to load from resources
    if (translator->load(QLocale(langCode), "packageinstaller", "_", ":/i18n")) {
        return true;
    }
    
    // 2. Try to load from the file system
    QStringList searchPaths = {
        "/opt/packageinstaller/translations",
        QCoreApplication::applicationDirPath() + "/translations",
        "translations"
    };
    for (const QString &path : searchPaths) {
        if (translator->load("packageinstaller_" + langCode, path)) {
            return true;
        }
    }
    return false;
}

static QString configDir()
{
    QString dir = QString::fromUtf8(qgetenv("HOME")) + "/.cache/LinuxAppInstallerConfig";
    QDir().mkpath(dir);
    return dir;
}

static QQmlApplicationEngine *g_engine = nullptr;

extern QSystemTrayIcon *g_trayIcon;

class Backend : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool hasTray READ hasTray NOTIFY hasTrayChanged)
    Q_PROPERTY(QString aiModel READ aiModel WRITE setAiModel NOTIFY aiModelChanged)
    Q_PROPERTY(bool accentOnlyColors READ accentOnlyColors WRITE setAccentOnlyColors NOTIFY accentOnlyColorsChanged)
    Q_PROPERTY(bool alwaysShowConsole READ alwaysShowConsole WRITE setAlwaysShowConsole NOTIFY alwaysShowConsoleChanged)
    Q_PROPERTY(bool waitingForInstance READ waitingForInstance NOTIFY waitingForInstanceChanged)
    Q_PROPERTY(bool systemColors READ systemColors WRITE setSystemColors NOTIFY systemColorsChanged)
    Q_PROPERTY(QString lastInstalledBinary READ lastInstalledBinary NOTIFY lastInstalledBinaryChanged)
    Q_PROPERTY(QString packageType READ packageType NOTIFY packageTypeChanged)
    Q_PROPERTY(bool showConsole READ showConsole WRITE setShowConsole NOTIFY showConsoleChanged)
    Q_PROPERTY(bool updatingPackageList READ updatingPackageList NOTIFY updatingPackageListChanged)
    Q_PROPERTY(QString executable      READ executable       WRITE setExecutable      NOTIFY executableChanged)
    Q_PROPERTY(QString execCommand     READ execCommand      WRITE setExecCommand     NOTIFY execCommandChanged)
    Q_PROPERTY(QString iconPath        READ iconPath         WRITE setIconPath        NOTIFY iconPathChanged)
    Q_PROPERTY(QString appName         READ appName          WRITE setAppName         NOTIFY appNameChanged)
    Q_PROPERTY(QString appDescription  READ appDescription   WRITE setAppDescription  NOTIFY appDescriptionChanged)
    Q_PROPERTY(QString appCategory     READ appCategory      WRITE setAppCategory     NOTIFY appCategoryChanged)
    Q_PROPERTY(QString archiveLocation READ archiveLocation                           NOTIFY archiveLocationChanged)
    Q_PROPERTY(bool    hasToken        READ hasToken                                  NOTIFY hasTokenChanged)
    Q_PROPERTY(bool    aiAnalyzing     READ aiAnalyzing                               NOTIFY aiAnalyzingChanged)
    Q_PROPERTY(QString lastInstalledFlatpakId READ lastInstalledFlatpakId NOTIFY lastInstalledFlatpakIdChanged)
    Q_PROPERTY(int installProgress READ installProgress NOTIFY installProgressChanged)
    Q_PROPERTY(QString aiProvider READ aiProvider WRITE setAiProvider NOTIFY aiProviderChanged)
    Q_PROPERTY(bool hasGeminiToken READ hasGeminiToken NOTIFY hasGeminiTokenChanged)
    Q_PROPERTY(bool hasHuggingFaceToken READ hasHuggingFaceToken NOTIFY hasHuggingFaceTokenChanged)
    Q_PROPERTY(bool hasOpenAiToken      READ hasOpenAiToken      NOTIFY hasOpenAiTokenChanged)
    Q_PROPERTY(bool hasMistralToken     READ hasMistralToken     NOTIFY hasMistralTokenChanged)
    Q_PROPERTY(QString appimageLocation    READ appimageLocation    NOTIFY appimageLocationChanged)
    Q_PROPERTY(QString aiAppName           READ aiAppName           WRITE setAiAppName        NOTIFY aiAppNameChanged)
    Q_PROPERTY(QString aiAppDescription    READ aiAppDescription    WRITE setAiAppDescription NOTIFY aiAppDescriptionChanged)
    Q_PROPERTY(QString aiAppCategory       READ aiAppCategory       WRITE setAiAppCategory    NOTIFY aiAppCategoryChanged)
    Q_PROPERTY(bool    aiAppimageAnalyzing READ aiAppimageAnalyzing NOTIFY aiAppimageAnalyzingChanged)
    Q_PROPERTY(bool    hasAiAccess         READ hasAiAccess         NOTIFY hasAiAccessChanged)
    Q_PROPERTY(bool    aiEnabled           READ aiEnabled           WRITE setAiEnabled        NOTIFY aiEnabledChanged)


    Q_PROPERTY(bool archerror READ archerror NOTIFY archerrorChanged)
    Q_PROPERTY(bool archsuccess READ archsuccess NOTIFY archsuccessChanged)

public:
    // constructor
    explicit Backend(QObject *parent = nullptr)
        : QObject(parent)
        , m_networkManager(new QNetworkAccessManager(this))
    {

        QTimer::singleShot(0, this, [this]() {
            isArch();
        });

        QFile fmod(configDir() + "/ai_model.txt");
        if (fmod.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(fmod.readAll()).trimmed();
            if (!val.isEmpty()) m_aiModel = val;
            fmod.close();
        }

        QFile flm(configDir() + "/light_mode.txt");
        if (flm.open(QIODevice::ReadOnly | QIODevice::Text)) {
            m_lightMode = QString::fromUtf8(flm.readAll()).trimmed() == "1";
            flm.close();
        }

        QFile fprov(configDir() + "/ai_provider.txt");
        if (fprov.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(fprov.readAll()).trimmed();
            if (!val.isEmpty()) m_aiProvider = val;
            fprov.close();
        }

        QFile fa(configDir() + "/always_show_console.txt");
        if (fa.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(fa.readAll()).trimmed();
            m_alwaysShowConsole = (val == "1");
            fa.close();
        }

        // Load saved AI state
        QFile f(configDir() + "/ai_enabled.txt");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(f.readAll()).trimmed();
            m_aiEnabled = (val != "0");
            f.close();
        }

        QFile fsc(configDir() + "/system_colors.txt");
        if (fsc.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(fsc.readAll()).trimmed();
            m_systemColors = (val == "1");
            fsc.close();
        }

        QFile fac(configDir() + "/accent_only_colors.txt");
        if (fac.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(fac.readAll()).trimmed();
            m_accentOnlyColors = (val == "1");
            fac.close();
        }

        // after loading m_aiEnabled — add:
        QFile fc(configDir() + "/show_console.txt");
        if (fc.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(fc.readAll()).trimmed();
            m_showConsole = (val != "0");
            fc.close();
        }
        QTimer::singleShot(0, this, [this]() {
            if (!hasInternet() && m_aiEnabled == 1) {
                emit noInternetDialog();
            }
        });
        // Auto-update arch-packages.txt if pacman DB is newer
        QTimer::singleShot(0, this, [this]() {
            QString outputFile = configDir() + "/arch-packages.txt";
            QString pacmanDb   = "/var/lib/pacman/local";

            QFileInfo outInfo(outputFile);
            QFileInfo dbInfo(pacmanDb);

            if (!outInfo.exists() || dbInfo.lastModified() > outInfo.lastModified()) {
                m_updatingPackageList = true;
                emit updatingPackageListChanged();

                QProcess *gen = new QProcess(this);
                connect(gen, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                        this, [this, gen, outputFile](int exitCode, QProcess::ExitStatus) {
                            gen->deleteLater();
                            m_updatingPackageList = false;
                            emit updatingPackageListChanged();
                            if (!QFileInfo::exists(outputFile) || QFileInfo(outputFile).size() == 0)
                                emitLog("Failed to auto-update Arch package list (exit "
                                            + QString::number(exitCode) + ")", "red");

                        });
                gen->start("/bin/bash", {"-c", "pacman -Sl | awk '{print $2}' > " + outputFile});
            }
        });
        QString depsDir = configDir();
        m_depsWatcher = new QFileSystemWatcher(this);
        m_depsWatcher->addPath(depsDir);
        connect(m_depsWatcher, &QFileSystemWatcher::directoryChanged,
                this, [this, depsDir]() {
                    QString reqFile = depsDir + "/deps_edit_request.json";
                    if (!QFile::exists(reqFile) || !isDependenciesSwitch()) return;

                    QFile f(reqFile);
                    if (!f.open(QIODevice::ReadOnly)) return;
                    QByteArray data = f.readAll();
                    f.close();

                    QJsonDocument doc = QJsonDocument::fromJson(data);
                    if (!doc.isObject()) return;

                    QJsonObject obj = doc.object();

                    // Check if this file is for our instance
                    QString fileLockNum = obj["lock_number"].toString("0");
                    QString myLockNum = "0";
                    if (!m_myLockFilePath.isEmpty()) {
                        QRegularExpression reLock("lock(\\d+)$");
                        QRegularExpressionMatch lm = reLock.match(m_myLockFilePath);
                        if (lm.hasMatch()) myLockNum = lm.captured(1);
                    }
                    if (fileLockNum != myLockNum) return; // not ours — ignore

                    QFile::remove(reqFile);

                    QJsonArray deps = obj["deps"].toArray();
                    emit showDepsEditWindow(deps);
                });
    }

    bool hasPKGBUILD(const QString &filename)
    {
        struct archive *a = archive_read_new();
        archive_read_support_filter_all(a);
        archive_read_support_format_all(a);

        if (archive_read_open_filename(a, filename.toStdString().c_str(), 10240) != ARCHIVE_OK) {
            archive_read_free(a);
            return false;
        }

        struct archive_entry *entry;
        while (archive_read_next_header(a, &entry) == ARCHIVE_OK) {
            string fname = archive_entry_pathname(entry);
            if (fname == ".PKGINFO") {
                archive_read_free(a);
                return true;
            }
            archive_read_data_skip(a);
        }

        archive_read_free(a);
        return false;
    }

    bool hasExtension(const QString &filePath, const QString &extension) {
        QFileInfo fileInfo(filePath);
        return fileInfo.suffix().compare(extension, Qt::CaseInsensitive) == 0;
    }

    Q_INVOKABLE bool isDirectory(const QString &path) {
        QFileInfo info(path);
        return info.isDir();
    }

    // ── Getters
    bool hasHuggingFaceToken() const {
        QFile f(configDir() + "/huggingface_token.txt");
        if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return !f.readAll().trimmed().isEmpty();
    }
    bool hasOpenAiToken() const {
        QFile f(configDir() + "/openai_token.txt");
        if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return !f.readAll().trimmed().isEmpty();
    }

    bool hasMistralToken() const {
        QFile f(configDir() + "/mistral_token.txt");
        if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return !f.readAll().trimmed().isEmpty();
    }

    QString aiProvider() const { return m_aiProvider; }
    bool hasGeminiToken() const
    {
        QFile f(configDir() + "/gemini_token.txt");
        if (!f.exists()) return false;
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return !f.readAll().trimmed().isEmpty();
    }


    bool accentOnlyColors() const { return m_accentOnlyColors; }
    bool waitingForInstance() const { return m_waitingForInstance; }
    QString m_lastInstalledFlatpakId;
    QString lastInstalledFlatpakId() const { return m_lastInstalledFlatpakId; }
    bool systemColors() const { return m_systemColors; }
    QString lastInstalledBinary() const { return m_lastInstalledBinary; }
    QString packageType() const { return m_packageType; }
    int installProgress() const { return m_installProgress; }
    bool showConsole() const { return m_showConsole; }
    QString executable()          const { return m_executable; }
    QString execCommand()         const { return m_execCommand; }
    QString iconPath()            const { return m_iconPath; }
    QString appName()             const { return m_appName; }
    QString appDescription()      const { return m_appDescription; }
    QString appCategory()         const { return m_appCategory; }
    QString archiveLocation()     const { return m_archiveLocation; }
    bool    aiAnalyzing()         const { return m_aiAnalyzing; }
    QString appimageLocation()    const { return m_appimageLocation; }
    QString aiAppName()           const { return m_aiAppName; }
    QString aiAppDescription()    const { return m_aiAppDescription; }
    QString aiAppCategory()       const { return m_aiAppCategory; }
    bool    aiAppimageAnalyzing() const { return m_aiAppimageAnalyzing; }
    bool    aiEnabled()           const { return m_aiEnabled; }
    bool alwaysShowConsole() const { return m_alwaysShowConsole; }
    QString aiModel() const { return m_aiModel; }

    QString greencolor() {
        if (m_lightMode) {
            return "#08631f";
        } else {
            return "lightgreen";
        }
    }
    QString greycolor() {
        if (m_lightMode) {
            return "#666565";
        } else {
            return "#aaaaaa";
        }
    }

    QString orange() {
        if (m_lightMode) {
            return "#ed8515";
        } else {
            return "#ffb86c";
        }
    }

    bool archerror() const { return m_archerror; }
    bool archsuccess() const { return m_archsuccess; }

    bool m_archerror = false;
    bool m_archsuccess = false;

    bool hasToken() const
    {
        QFile f(configDir() + "/token.txt");
        if (!f.exists()) return false;
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return !f.readAll().trimmed().isEmpty();
    }

    Q_INVOKABLE void resetArchStatus() {
        if (m_archerror) {
            m_archerror = false;
            emit archerrorChanged();
        }
        if (m_archsuccess) {
            m_archsuccess = false;
            emit archsuccessChanged();
        }
    }

    Q_INVOKABLE void rmAlltempfiles() {
        QString cachePath = QDir::homePath() + "/.cache";
        QString depstransfile = cachePath + "/LinuxAppInstallerConfig/deps_edit_request.json";

        if (QFile::exists(cachePath + "/extract_done"))
            QFile::remove(cachePath + "/extract_done");
        if (QFile::exists(cachePath + "/convert_done"))
            QFile::remove(cachePath + "/convert_done");
        if (QDir(cachePath + "/PackageInstaller").exists())
            QDir(cachePath + "/PackageInstaller").removeRecursively();
        if (QDir(cachePath + "/appimage-inspect").exists())
            QDir(cachePath + "/appimage-inspect").removeRecursively();

        // Remove OUR lock file — unlocks the next in queue
        if (!m_myLockFilePath.isEmpty() && QFile::exists(m_myLockFilePath)) {
            QFile::remove(m_myLockFilePath);
            m_myLockFilePath = "";
        }

        if (QFile::exists(depstransfile)) QFile::remove(depstransfile);

        // If we are the only running instance — remove the entire lock directory
        // (removes debris from previous crashes)
        static QSharedMemory sharedMemory("appPackageInstaller");
        if (sharedMemory.create(1)) {
            QString lockPath = cachePath + "/InstallerLock";
            QDir lockDir(lockPath);
            if (lockDir.exists()) {
                lockDir.removeRecursively();
            }
        }
    }
    void markTime(const char* label) {
        auto now = std::chrono::high_resolution_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - getStartTime()).count();
        std::ofstream f(std::string(getenv("HOME")) + "/Desktop/timing.txt", std::ios::app);
        f << ms << "ms — " << label << "\n";
    }

    Q_INVOKABLE void markTimeQml(const QString &label) {
        markTime(label.toUtf8().constData());
    }

    void isArch() {
        const char* path_env = std::getenv("PATH");
        if (!path_env) {
            emit notArch();
            return;
        }
        string path_str(path_env);
        stringstream ss(path_str);
        string directory;

        while (getline(ss, directory, ':')) {
            try {
                filesystem::path potential_path = filesystem::path(directory) / "pacman";
                if (filesystem::exists(potential_path)) {
                    return;
                }
            } catch (...) {
                continue;
            }
        }
        emit notArch();
    }

    Q_INVOKABLE QString replaceNewlinesWithBr(const QString &text) {
        QString result = text; // Making a copy
        result.replace("\n", "<br/>");
        return result;
    }


    Q_INVOKABLE void rmNotAlltempfiles() {
        QString cachePath = QDir::homePath() + "/.cache";

        if (QFile::exists(cachePath + "/extract_done"))
            QFile::remove(cachePath + "/extract_done");
        if (QFile::exists(cachePath + "/convert_done"))
            QFile::remove(cachePath + "/convert_done");

        // Asynchronous removal of heavy directories
        QStringList dirsToRemove;
        if (QDir(cachePath + "/PackageInstaller").exists())
            dirsToRemove << cachePath + "/PackageInstaller";
        if (QDir(cachePath + "/appimage-inspect").exists())
            dirsToRemove << cachePath + "/appimage-inspect";

        if (!dirsToRemove.isEmpty()) {
            QFuture<void> future = QtConcurrent::run([dirsToRemove]() {
                for (const QString &dir : dirsToRemove)
                    QDir(dir).removeRecursively();
            });
            Q_UNUSED(future)
        }
    }

    void setAppDescription(const QString &val) {
        if (m_appDescription == val) return;
        m_appDescription = val;
        m_appDescriptionFromAI = false;
        emit appDescriptionChanged();
    }

    // ── Setters ──────────────────────────────

    void setAlwaysShowConsole(bool val) {
        if (m_alwaysShowConsole == val) return;
        m_alwaysShowConsole = val;
        emit alwaysShowConsoleChanged();
        // persist to config file if needed
        QFile f(configDir() + "/always_show_console.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    void setAiModel(const QString &val) {
        if (m_aiModel == val) return;
        m_aiModel = val;
        emit aiModelChanged();
        QFile f(configDir() + "/ai_model.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val.toUtf8());
            f.close();
        }
    }

    void setAiProvider(const QString &val) {
        if (m_aiProvider == val) return;
        m_aiProvider = val;
        // Load saved model for the new provider
        QFile fm(configDir() + "/ai_model_" + val + ".txt");
        if (fm.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString savedModel = QString::fromUtf8(fm.readAll()).trimmed();
            if (m_aiModel != savedModel) {
                m_aiModel = savedModel;
                emit aiModelChanged();
            }
            fm.close();
        } else if (!m_aiModel.isEmpty()) {
            m_aiModel = "";
            emit aiModelChanged();
        }
        emit aiProviderChanged();
        QFile f(configDir() + "/ai_provider.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val.toUtf8());
            f.close();
        }
    }

    void setSystemColors(bool val) {
        if (m_systemColors == val) return;
        m_systemColors = val;
        emit systemColorsChanged();
        QFile f(configDir() + "/system_colors.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    void setAccentOnlyColors(bool val) {
        if (m_accentOnlyColors == val) return;
        m_accentOnlyColors = val;
        emit accentOnlyColorsChanged();
        QFile f(configDir() + "/accent_only_colors.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    void setShowConsole(bool val) {
        if (m_showConsole == val) return;
        m_showConsole = val;
        emit showConsoleChanged();
        QFile f(configDir() + "/show_console.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }
    void setExecutable(const QString &val) {
        if (m_executable == val) return;
        m_executable = val;
        emit executableChanged();

        if (!m_appNameCustomized && !m_appNameFromAI) {
            QString derived = execBaseName(val);
            if (!derived.isEmpty()) derived[0] = derived[0].toUpper();
            setAppNameRaw(derived);
        }

        if (!m_execCommandCustomized) {
            buildDefaultExecCommand();
        }
    }

    void sendMistralRequest(const QString &systemPrompt, const QString &userMsg,
                            std::function<void(const QString&, const QString&, const QString&, const QString&)> onSuccess,
                            std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/mistral_token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) { onError("Mistral token not found"); return; }
        const QString apiKey = QString::fromUtf8(tf.readAll()).trimmed(); tf.close();

        QJsonObject body;
        body["model"]       = m_aiModel.isEmpty() ? "mistral-small-latest" : m_aiModel;
        body["max_tokens"]  = 1024;
        body["temperature"] = 0.0;
        QJsonArray msgs;
        QJsonObject sys; sys["role"] = "system"; sys["content"] = systemPrompt; msgs.append(sys);
        QJsonObject usr; usr["role"] = "user";   usr["content"] = userMsg;      msgs.append(usr);
        body["messages"] = msgs;

        QNetworkRequest req(QUrl("https://api.mistral.ai/v1/chat/completions"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

        QNetworkReply *reply = m_networkManager->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError]() {
            reply->deleteLater();
            int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (status == 401 || status == 403) { onError("Mistral: invalid token");
                if (status == 401) {
                    emit showAiCustomErrorDialog("Mistral", "Invalid API key (403)", 0);
                    return;
                } else {
                    emit showAiCustomErrorDialog("Mistral", reply->errorString(), 1);
                    return;
                }
            }
            if (status == 429) { onError("Mistral: rate limit (429)"); emit showAiCustomErrorDialog("Mistral", "Rate limit (429)", 1); return; }
            if (reply->error() != QNetworkReply::NoError) {
                onError("Mistral request failed: " + reply->errorString());
                emit showAiCustomErrorDialog("Mistral", reply->errorString(), 1);
                return;
            }
            parseAndDeliverResult(reply->readAll(), onSuccess, onError);
        });
    }

    void setExecCommand(const QString &val) {
        if (m_execCommand == val) return;
        m_execCommand = val;
        m_execCommandCustomized = true;
        emit execCommandChanged();
    }

    void setIconPath(const QString &val) {
        if (m_iconPath == val) return;
        m_iconPath = val;
        emit iconPathChanged();
    }
    void setAppName(const QString &val) {
        if (m_appName == val) return;
        m_appName = val;
        m_appNameCustomized = true;
        m_appNameFromAI = false;
        emit appNameChanged();
    }

    void setAppNameFromAI(const QString &val) {
        if (m_appName == val) return;
        m_appName = val;
        m_appNameFromAI = true;
        m_appNameCustomized = false;
        emit appNameChanged();
    }

    void setAppNameRaw(const QString &val) {
        if (m_appName == val) return;
        m_appName = val;
        emit appNameChanged();
    }

    void setAiAppDescription(const QString &val) {
        if (m_aiAppDescription == val) return;
        m_aiAppDescription = val;
        if (m_aiFirstAppimageDescription.isEmpty())
            m_aiFirstAppimageDescription = val;
        emit aiAppDescriptionChanged();
        emit aiAppDescriptionUpdated();
    }

    void setAppCategory(const QString &val) {
        if (m_appCategory == val) return;
        m_appCategory = val;
        m_appCategoryFromAI = false;
        emit appCategoryChanged();
    }

    void setAiAnalyzing(bool val) {
        if (m_aiAnalyzing == val) return;
        m_aiAnalyzing = val;
        emit aiAnalyzingChanged();
    }

    void setAiAppName(const QString &val) {
        if (m_aiAppName == val) return;
        m_aiAppName = val;
        emit aiAppNameChanged();
    }

    void setAiAppCategory(const QString &val) {
        if (m_aiAppCategory == val) return;
        m_aiAppCategory = val;
        emit aiAppCategoryChanged();
    }
    void setAiAppimageAnalyzing(bool val) {
        if (m_aiAppimageAnalyzing == val) return;
        m_aiAppimageAnalyzing = val;
        emit aiAppimageAnalyzingChanged();
    }

    void setAiEnabled(bool val) {
        if (m_aiEnabled == val) return;
        m_aiEnabled = val;
        emit aiEnabledChanged();

        // Save state
        QFile f(configDir() + "/ai_enabled.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }

        bool hasKey = false;
        if      (m_aiProvider == "gemini")      hasKey = hasGeminiToken();
        else if (m_aiProvider == "openai")      hasKey = hasOpenAiToken();
        else if (m_aiProvider == "huggingface") hasKey = hasHuggingFaceToken();
        else if (m_aiProvider == "mistral")     hasKey = hasMistralToken();
        else                                    hasKey = hasToken(); // openrouter

        bool effective = m_aiEnabled && hasKey && hasInternet();
        if (m_hasAiAccess != effective) {
            m_hasAiAccess = effective;
            emit hasAiAccessChanged();
        }
    }

    // In Q_PROPERTY — not needed, just save to a file

    Q_INVOKABLE void launchNewInstance(const QString &filePath)
    {
        QProcess::startDetached(QCoreApplication::applicationFilePath(), {filePath, "--silent"});
    }

    Q_INVOKABLE void launchInstalledApp()
    {
        if (m_lastInstalledBinary.startsWith("__flatpak__:")) {
            QString appId = m_lastInstalledBinary.mid(12); // after "__flatpak__:"
            if (!appId.isEmpty()) {
                QProcess::startDetached("flatpak", {"run", appId});
            }
            return;
        }
        if (!m_lastInstalledBinary.isEmpty()) {
            QProcess::startDetached(m_lastInstalledBinary, {});
        }
    }

    Q_INVOKABLE bool loadNotificationsEnabled() const
    {
        QFile f(configDir() + "/notifications.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return QString::fromUtf8(f.readAll()).trimmed() == "1";
    }

    Q_INVOKABLE void saveNotificationsEnabled(bool val)
    {
        QFile f(configDir() + "/notifications.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    Q_INVOKABLE bool loadDependenciesSwitch() const
    {
        QFile f(configDir() + "/dependencies.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return QString::fromUtf8(f.readAll()).trimmed() == "1";
    }

    // backend.cpp
    Q_INVOKABLE QVariantList getDependencies() {
        QVariantList list;

        // This can be loaded from a .deb or .rpm file
        QVariantMap dep1;
        dep1["key"] = "Depends";
        dep1["value"] = "libc6 (>= 2.31)";

        QVariantMap dep2;
        dep2["key"] = "Recommends";
        dep2["value"] = "python3";

        QVariantMap dep3;
        dep3["key"] = "Suggests";
        dep3["value"] = "libcurl4";

        list << dep1 << dep2 << dep3;
        return list;
    }

    Q_INVOKABLE void saveDependenciesSwitch(bool val)
    {
        QFile f(configDir() + "/dependencies.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    Q_INVOKABLE void saveConsoleWidthEnabled(bool val)
    {
        QFile f(configDir() + "/consoleWidth.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    Q_INVOKABLE void saveConsoleFontFamily(const QString &val)
    {
        QFile f(configDir() + "/console_font_family.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val.toUtf8());
            f.close();
        }
    }

    Q_INVOKABLE QString loadConsoleFontFamily() const
    {
        QFile f(configDir() + "/console_font_family.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return "monospace";
        QString val = QString::fromUtf8(f.readAll()).trimmed();
        return val.isEmpty() ? "monospace" : val;
    }

    Q_INVOKABLE void saveConsoleFontBold(bool val)
    {
        QFile f(configDir() + "/console_font_bold.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    Q_INVOKABLE bool loadConsoleFontBold() const
    {
        QFile f(configDir() + "/console_font_bold.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return QString::fromUtf8(f.readAll()).trimmed() == "1";
    }

    Q_INVOKABLE void saveConsoleFontSize(int val)
    {
        QFile f(configDir() + "/console_font_size.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(QString::number(val).toUtf8());
            f.close();
        }
    }

    Q_INVOKABLE int loadConsoleFontSize() const
    {
        QFile f(configDir() + "/console_font_size.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return 12;
        bool ok;
        int val = QString::fromUtf8(f.readAll()).trimmed().toInt(&ok);
        if (!ok || val < 8 || val > 24) return 12;
        return val;
    }

    Q_INVOKABLE bool loadConsoleWidthEnabled() const
    {
        QFile f(configDir() + "/consoleWidth.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return QString::fromUtf8(f.readAll()).trimmed() == "1";
    }

    Q_INVOKABLE void sendDesktopNotification(const QString &type)
    {
        QString title, body;

        if (type == "success") {
            title = tr("Installation complete");
            body  = m_installingFileName.isEmpty()
                       ? tr("Package installed successfully")
                       : tr("Successfully installed: ") + m_installingFileName;
        } else if (type == "error") {
            title = tr("Installation failed");
            body  = m_installingFileName.isEmpty()
                       ? tr("An error occurred during installation")
                       : tr("Failed to install: ") + m_installingFileName;
            // for error — without Open button
            QProcess *notif = new QProcess(this);
            connect(notif, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    notif, &QProcess::deleteLater);
            notif->start("notify-send", {
                                            "--app-name=Linux App Installer",
                                            "--icon=dialog-error",
                                            "--urgency=normal",
                                            title, body
                                        });
            return;
        } else {
            return;
        }

        // success — with Open button that launches the application
        QProcess *notif = new QProcess(this);
        connect(notif, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, notif](int, QProcess::ExitStatus) {
                    QString out = QString::fromUtf8(notif->readAllStandardOutput()).trimmed();
                    if (!out.isEmpty() && !m_lastInstalledBinary.isEmpty()) {
                        QProcess::startDetached(m_lastInstalledBinary, {});
                        emit notificationActionClicked();
                    }
                    notif->deleteLater();
                });
        notif->start("notify-send", {
                                        "--app-name=Linux App Installer",
                                        "--icon=system-software-install",
                                        "--urgency=normal",
                                        "--action=open=" + tr("Open"),
                                        "--wait",
                                        title, body
                                    });
    }
    // ─────────────────────────────────────────
    //  generateArchPackageList
    // ─────────────────────────────────────────

    Q_INVOKABLE bool loadDebNoAiWarningDisabled() const {
        QFile f(configDir() + "/deb_no_ai_warning_disabled.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return QString::fromUtf8(f.readAll()).trimmed() == "1";
    }
    Q_INVOKABLE void saveDebNoAiWarningDisabled(bool val) {
        QFile f(configDir() + "/deb_no_ai_warning_disabled.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }
    Q_INVOKABLE void generateArchPackageList()
    {
        QString outputFile = configDir() + "/arch-packages.txt";

        if (QFileInfo::exists(outputFile)) return;

        emitLog("Generating Arch package list (first run)...");

        QProcess *gen = new QProcess(this);
        connect(gen, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, gen, outputFile](int exitCode, QProcess::ExitStatus) {
                    gen->deleteLater();
                    if (QFileInfo::exists(outputFile) && QFileInfo(outputFile).size() > 0)
                        emitLog("Arch package list generated successfully", greencolor());
                    else
                        emitLog("Failed to generate Arch package list (exit " + QString::number(exitCode) + ")", "red");
                });
        gen->start("/bin/bash", {"-c", "pacman -Sl | awk '{print $2}' > " + outputFile});
    }

    Q_INVOKABLE bool hasInternet() {
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) return false;

        sockaddr_in server{};
        server.sin_family = AF_INET;
        server.sin_port = htons(53);
        inet_pton(AF_INET, "8.8.8.8", &server.sin_addr);

        struct timeval timeout;
        timeout.tv_sec = 2;
        timeout.tv_usec = 0;
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

        bool connected = (::connect(sock, (struct sockaddr*)&server, sizeof(server)) == 0);
        close(sock);
        return connected;
    }

    Q_INVOKABLE bool loadLightMode() const
    {
        QFile f(configDir() + "/light_mode.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return QString::fromUtf8(f.readAll()).trimmed() == "1";
    }

    Q_INVOKABLE void saveLightMode(bool val)
    {
        m_lightMode = val;
        QFile f(configDir() + "/light_mode.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    Q_INVOKABLE void setInstallProgress(int val) {
        val = qBound(0, val, 100);
        if (m_installProgress == val) return;
        m_installProgress = val;
        emit installProgressChanged();
    }

    // ─────────────────────────────────────────
    //  analyzeWithAI  (for archive)
    // ─────────────────────────────────────────
    Q_INVOKABLE void analyzeWithAI(const QString &rootDir,
                                   const QString &archivePath,
                                   const QString &executablePath)
    {
        if (!m_hasAiAccess) {
            emitLog("No AI access — skipping AI metadata analysis", greycolor());
            return;
        }

        int thisRequestId = ++m_aiRequestId;

        setAiAnalyzing(true);
        emitLog("Analyzing app with AI...", greycolor());

        // Structure for passing scan result between threads
        struct ScanResult {
            QStringList execs;
            QString context;
        };

        const QString archiveFileName  = QFileInfo(archivePath).fileName();
        const QString executableFileName = executablePath.isEmpty()
                                               ? QString()
                                               : QFileInfo(executablePath).fileName();

        // File scan + context gathering — in background thread
        QFuture<ScanResult> scanFuture = QtConcurrent::run(
            [this, rootDir, archivePath, archiveFileName, executableFileName]() -> ScanResult
            {
                ScanResult result;

                result.execs = findExecutables(rootDir, archivePath);

                result.context += "Archive filename: " + archiveFileName + "\n";
                if (!executableFileName.isEmpty())
                    result.context += "Currently selected executable: " + executableFileName + "\n";

                if (!result.execs.isEmpty()) {
                    QStringList execNames;
                    for (const QString &e : result.execs)
                        execNames << QFileInfo(e).fileName();
                    result.context += "Available executables: " + execNames.join(", ") + "\n";
                }

                QStringList infoFiles;
                QDirIterator it(rootDir, QDirIterator::Subdirectories);
                while (it.hasNext()) {
                    QString p = it.next();
                    QString fn = QFileInfo(p).fileName().toLower();
                    if (fn.startsWith("readme") || fn.startsWith("about") ||
                        fn == "description"     || fn == "info.txt"       ||
                        fn == "changelog"       || fn.startsWith("release"))
                        infoFiles << p;
                }
                std::sort(infoFiles.begin(), infoFiles.end(), [](const QString &a, const QString &b) {
                    bool aR = QFileInfo(a).fileName().toLower().startsWith("readme");
                    bool bR = QFileInfo(b).fileName().toLower().startsWith("readme");
                    return (int)aR > (int)bR;
                });
                for (const QString &infoPath : infoFiles) {
                    QFile f(infoPath);
                    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
                    QString content = QString::fromUtf8(f.read(4096)).trimmed();
                    if (content.isEmpty()) continue;
                    if (content.length() > 3000) content = content.left(3000) + "\n[truncated]";
                    result.context += "\n--- " + QFileInfo(infoPath).fileName() + " ---\n" + content + "\n";
                    break;
                }

                QStringList topFiles;
                for (const QString &e : QDir(rootDir).entryList(QDir::Files | QDir::NoDotAndDotDot, QDir::Name))
                    topFiles << e;
                if (!topFiles.isEmpty())
                    result.context += "\nTop-level files: " + topFiles.mid(0, 20).join(", ") + "\n";

                return result;
            });

        auto *scanWatcher = new QFutureWatcher<ScanResult>(this);
        connect(scanWatcher, &QFutureWatcher<ScanResult>::finished,
                this, [this, scanWatcher, thisRequestId, executablePath]()
                {
                    ScanResult sr = scanWatcher->result();
                    scanWatcher->deleteLater();

                    if (thisRequestId != m_aiRequestId) {
                        setAiAnalyzing(false);
                        return;
                    }

                    sendAiRequest(sr.context,
                                  [this, thisRequestId, allExecs = sr.execs, executablePath]
                                  (const QString &name, const QString &desc, const QString &cat, const QString &execHint)
                                  {
                                      if (thisRequestId != m_aiRequestId) return;
                                      if (!name.isEmpty()) {
                                          setAppNameFromAI(name);
                                          emitLog("AI → name: " + name, greencolor());
                                      }
                                      if (!desc.isEmpty()) { setAppDescriptionFromAI(desc); emitLog("AI → description: " + desc, greencolor()); }
                                      if (!cat.isEmpty())  { QString c = cat; if (!c.endsWith(";")) c += ";"; setAppCategoryFromAI(c); emitLog("AI → category: " + c, greencolor()); }

                                      if (executablePath.isEmpty() && !allExecs.isEmpty()) {
                                          if (!execHint.isEmpty()) {
                                              for (const QString &execPath : allExecs) {
                                                  if (QFileInfo(execPath).fileName().compare(execHint, Qt::CaseInsensitive) == 0) {
                                                      emitLog("AI → executable: " + execHint, greencolor());
                                                      emit aiSuggestedExecutable(execPath);
                                                      break;
                                                  }
                                              }
                                          } else {
                                              emit aiSuggestedExecutable(allExecs.first());
                                          }
                                      }
                                      setAiAnalyzing(false);
                                  },
                                  [this, thisRequestId](const QString &err) {
                                      if (thisRequestId != m_aiRequestId) return;
                                      emitLog(err, "red");
                                      setAiAnalyzing(false);
                                  });
                });
        scanWatcher->setFuture(scanFuture);
    }

    Q_INVOKABLE bool loadRpmNoAiWarningDisabled() const {
        QFile f(configDir() + "/rpm_no_ai_warning_disabled.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
        return QString::fromUtf8(f.readAll()).trimmed() == "1";
    }
    Q_INVOKABLE void saveRpmNoAiWarningDisabled(bool val) {
        QFile f(configDir() + "/rpm_no_ai_warning_disabled.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val ? "1" : "0");
            f.close();
        }
    }

    Q_INVOKABLE bool isDirectoryPath(const QString &path) const {
        return QFileInfo(path).isDir();
    }


    Q_INVOKABLE void confirmAiAuthErrorInstall(bool proceed)
    {
        QString pkg = m_pendingAuthErrorPackage;
        m_pendingAuthErrorPackage = "";
        if (!proceed) {
            emitLog("Installation cancelled by user", greycolor());
            return;
        }
        emit showKillPacmanButton();
        installArchPkg(pkg);
    }

    // ─────────────────────────────────────────
    //  analyzeAppimageWithAI  — for AppImage
    // ─────────────────────────────────────────
    Q_INVOKABLE void analyzeAppimageWithAI(const QString &appImagePath)
    {
        if (!m_hasAiAccess) {
            emitLog("No AI access — skipping AI metadata analysis", greycolor());
            QString fallback = QFileInfo(appImagePath).baseName();
            fallback = fallback.split(QRegularExpression("[-_][0-9]")).first();
            if (!fallback.isEmpty()) fallback[0] = fallback[0].toUpper();
            setAiAppName(fallback);
            setAiAppDescription("");
            setAiAppCategory("Utility;");
            return;
        }

        setAiAppimageAnalyzing(true);
        emitLog("Analyzing AppImage with AI...", greycolor());

        QString context;
        context += "AppImage filename: " + QFileInfo(appImagePath).fileName() + "\n";
        context += "File type: AppImage (self-contained Linux application)\n";

        QString tmpDir = QString::fromStdString(string(getenv("HOME"))) + "/.cache/appimage-inspect";
        QDir().mkpath(tmpDir);

        QProcess *extract = new QProcess(this);
        extract->setWorkingDirectory(tmpDir);
        extract->start("/bin/bash", {"-c",
                                        "cd " + tmpDir + " && " + appImagePath + " --appimage-extract '*.desktop' 2>/dev/null; "
                                            + appImagePath + " --appimage-extract '*.png' 2>/dev/null; "
                                            + appImagePath + " --appimage-extract 'AppRun' 2>/dev/null; true"
                                    });
        extract->waitForFinished(5000);
        extract->deleteLater();

        QString squashfsRoot = tmpDir + "/squashfs-root";
        QDirIterator dit(squashfsRoot, {"*.desktop"}, QDir::Files, QDirIterator::Subdirectories);
        while (dit.hasNext()) {
            QFile f(dit.next());
            if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
            QString desktop = QString::fromUtf8(f.read(2048)).trimmed();
            if (!desktop.isEmpty())
                context += "\n--- .desktop file ---\n" + desktop + "\n";
            break;
        }

        QDir(squashfsRoot).removeRecursively();

        sendAiRequest(context,
                      [this](const QString &name, const QString &desc, const QString &cat, const QString &) {
                          if (!name.isEmpty()) { setAiAppName(name);        emitLog("AI → name: "     + name, greencolor()); }
                          if (!desc.isEmpty()) { setAiAppDescription(desc); emitLog("AI → description: " + desc, greencolor()); }
                          if (!cat.isEmpty())  { QString c = cat; if (!c.endsWith(";")) c += ";"; setAiAppCategory(c); emitLog("AI → category: " + c, greencolor()); }
                          setAiAppimageAnalyzing(false);
                      },
                      [this](const QString &err) {
                          emitLog(err, "red");
                          setAiAppimageAnalyzing(false);
                      });
    }

    Q_INVOKABLE void confirmDebWithoutAi(bool proceed)
    {
        QString loc = m_pendingDebLocation;
        m_pendingDebLocation = "";
        if (!proceed) {
            emitLog("Installation cancelled", greycolor());
            return;
        }
        doStartDebConversion(loc);
    }

    Q_INVOKABLE bool loadDonateHidden() const
    {
        return true/*QFileInfo::exists(configDir() + "/do_not_show_donate_content")*/;
    }

    Q_INVOKABLE void confirmRpmWithoutAi(bool proceed)
    {
        QString loc = m_pendingRpmLocation;
        m_pendingRpmLocation = "";
        if (!proceed) {
            emitLog("Installation cancelled", greycolor());
            return;
        }
        doStartRpmConversion(loc);
    }

    Q_INVOKABLE void onExecutableChanged(const QString &execPath)
    {
        Q_UNUSED(execPath)
    }

    Q_INVOKABLE void regenerateDescription()
    {
        if (!m_hasAiAccess) return;
        std::string extractedDir = getExtractedDir().toStdString();
        std::string rootDir      = normalizeExtractedDir(extractedDir);
        analyzeWithAI(QString::fromStdString(rootDir), m_archiveLocation, m_executable);
    }

    Q_INVOKABLE void resetDescriptionToFirst()
    {
        if (!m_aiFirstDescription.isEmpty()) {
            setAppDescriptionFromAI(m_aiFirstDescription);
        }
    }

    Q_INVOKABLE void confirmReload()
    {
        emit reloadQmlRequested();
    }

    bool hasAiAccess() const { return m_hasAiAccess; }

    bool isKnown(const QString &location) {
        if (isDirectory(location) || isKnownArchive(location) ||
            hasExtension(location, "flatpak") || hasExtension(location, "flatpakref") ||
            hasExtension(location, "appimage") || hasExtension(location, "rpm") ||
            hasExtension(location, "deb")) {
            return true;
        } else if (hasExtension(location, "sh")) {
            emit showShUnsapportedDialog();
            return false;
        }
        emit showUnknownError();
        return false;
    }

    // ─────────────────────────────────────────
    //  installAPP — entry point from QML
    // ─────────────────────────────────────────
    Q_INVOKABLE void installAPP(const QString &location)
    {
        m_installsuccess = false;
        if (isKnown(location)) {
            QString waitForLockFile = CreateLockFile();
            if (!waitForLockFile.isEmpty()) {
                m_waitingForInstance = true;
                emit waitingForInstanceChanged();
                emitLog("Waiting for another installation to finish...", greycolor());

                QFileSystemWatcher *watcher = new QFileSystemWatcher(this);
                watcher->addPath(QFileInfo(waitForLockFile).absolutePath());

                QObject::connect(watcher, &QFileSystemWatcher::directoryChanged,
                                 [this, watcher, waitForLockFile, location](const QString &) {
                                     if (!QFile::exists(waitForLockFile)) {
                                         m_waitingForInstance = false;
                                         emit waitingForInstanceChanged();
                                         watcher->deleteLater();
                                         InstallAppExternal(location);
                                     }
                                 });
            } else {
                InstallAppExternal(location);
            }
        }
    }


    void InstallAppExternal(const QString &location) {
        emit showKillPacmanButton();
        rmNotAlltempfiles();
        m_appNameFromAI = false;
        emitLog("Location: " + location);
        if (isDirectory(location)) {
            setInstallProgress(8);
            m_packageType = "dir"; emit packageTypeChanged();
            emitLog("Directory detected");
            emit showKillPacmanButton();

            QString cacheDir = QDir::homePath() + "/.cache/PackageInstaller";
            QDir(cacheDir).removeRecursively();
            QDir().mkpath(cacheDir);

            m_archiveLocation = location;
            emit archiveLocationChanged();

            setExecutable("");
            setExecCommandRaw("", false);
            setIconPath("");
            setAppNameRaw("");
            m_appNameCustomized    = false;
            m_appDescriptionFromAI = false;
            m_appCategoryFromAI    = false;
            m_aiFirstDescription = "";
            m_execCommandCustomized = false;
            setAppDescription("");
            setAppCategory("Utility;");

            auto future = QtConcurrent::run([this, location, cacheDir]() {
                return copyDirectory(location, cacheDir);
            });

            auto *watcher = new QFutureWatcher<bool>(this);
            connect(watcher, &QFutureWatcher<bool>::finished, this, [this, watcher, location]() {
                bool ok = watcher->result();
                watcher->deleteLater();
                if (!ok) {
                    emitLog("Failed to copy directory", "red");
                    emit showErrorDialog();
                    return;
                }
                emitLog("Directory copied", greencolor());
                setInstallProgress(31);
                emit switchToPage2();
            });
            watcher->setFuture(future);

        } else if (hasExtension(location, "deb")) {
            rmNotAlltempfiles();
            m_packageType = "deb"; emit packageTypeChanged();
            startDebConversion(location);
        } else if (hasExtension(location, "rpm")) {
            emit showKillPacmanButton();
            rmNotAlltempfiles();
            m_packageType = "rpm"; emit packageTypeChanged();
            startRpmConversion(location);
        }  else if (hasExtension(location, "appimage")) {
            rmNotAlltempfiles();
            m_packageType = "appimage"; emit packageTypeChanged();
            emitLog("AppImage detected");
            emit showKillPacmanButton();   // ← add this
            setInstallProgress(8);
            m_appimageLocation = location;
            emit appimageLocationChanged();
            setAiAppName("");
            setAiAppDescription("");
            setAiAppCategory("Utility;");
            m_aiFirstAppimageDescription = "";
            emit showAppimageDialog();
        } else if (hasExtension(location, "flatpakref"))  {
            rmNotAlltempfiles();
            m_packageType = "flatpak"; emit packageTypeChanged();
            emitLog("Flatpak ref detected");
            emit showKillPacmanButton();
            installFlatpak(location);
        } else if (hasExtension(location, "flatpak")) {
            rmNotAlltempfiles();
            m_packageType = "flatpak"; emit packageTypeChanged();
            emitLog("Flatpak package detected");
            emit showKillPacmanButton();
            installFlatpak(location);
        } else if (isKnownArchive(location)) {
            rmNotAlltempfiles();
            emitLog("Archive detected");
            startSmartArchiveExtraction(location);
        }
    }

    Q_INVOKABLE void debugMark(const QString &name) {
        QFile f(QDir::homePath() + "/Desktop/" + name);
        if (f.open(QIODevice::WriteOnly)) {
            f.close();
        }
    }


    QString CreateLockFile() {
        QString homeDir = QDir::homePath() + "/.cache";
        QDir lockDir(homeDir + "/InstallerLock");

        if (!lockDir.exists()) {
            QDir().mkpath(lockDir.path());
        }

        int maxNum = 0;
        QRegularExpression re("^lock(\\d+)$");

        for (const QFileInfo &fi : lockDir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot)) {
            QRegularExpressionMatch match = re.match(fi.fileName());
            if (match.hasMatch()) {
                int foundNum = match.captured(1).toInt();
                if (foundNum > maxNum) maxNum = foundNum;
            }
        }

        int newNum = maxNum + 1;
        QString lockFilePath = lockDir.filePath("lock" + QString::number(newNum));

        QFile file(lockFilePath);
        if (file.open(QIODevice::WriteOnly)) {
            file.close();
        } else {
            emitLog("Failed to create lock file", "red");
            return "";
        }

        // Remember OUR lock file
        m_myLockFilePath = lockFilePath;

        if (newNum == 1) {
            return "";  // we are first — start immediately
        } else {
            // Waiting for lock with number newNum-1
            return lockDir.filePath("lock" + QString::number(newNum - 1));
        }
    }



    // ─────────────────────────────────────────────
    //  Check: is the file a known archive
    // ─────────────────────────────────────────────
    static bool isKnownArchive(const QString &path)
    {
        // Check compound extensions first
        static const QStringList multiExts = {
            ".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst",
            ".tar.lz4", ".tar.lzma", ".tar.lz", ".tar.Z",
            ".tar.zst", ".tar.br",
        };
        for (const QString &ext : multiExts)
            if (path.endsWith(ext, Qt::CaseInsensitive)) return true;

        static const QStringList singleExts = {
            ".zip", ".tar", ".tgz", ".tbz2", ".txz", ".tzst",
            ".gz", ".bz2", ".xz", ".zst", ".lz4", ".lzma",
            ".7z", ".rar", ".lha", ".lzh", ".arj", ".cab",
            ".Z", ".br",
        };
        QString lower = path.toLower();
        for (const QString &ext : singleExts)
            if (lower.endsWith(ext)) return true;

        return false;
    }

    Q_INVOKABLE void reloadQml()
    {
        emit reloadQmlRequested();
    }

    Q_INVOKABLE void initAiAccess()
    {
        bool hasKey = false;
        if      (m_aiProvider == "gemini")      hasKey = hasGeminiToken();
        else if (m_aiProvider == "openai")      hasKey = hasOpenAiToken();
        else if (m_aiProvider == "huggingface") hasKey = hasHuggingFaceToken();
        else if (m_aiProvider == "mistral")     hasKey = hasMistralToken();
        else                                    hasKey = hasToken(); // openrouter
        bool val = m_aiEnabled && hasKey && hasInternet();
        if (m_hasAiAccess == val) return;
        m_hasAiAccess = val;
        emit hasAiAccessChanged();
    }

    Q_INVOKABLE void checkAiStatus(const QString &provider)
    {
        Q_UNUSED(provider)

        // Determine token and URL
        QString tokenFile, urlStr, model;
        bool isGemini = (m_aiProvider == "gemini");

        if      (m_aiProvider == "gemini")      tokenFile = configDir() + "/gemini_token.txt";
        else if (m_aiProvider == "openai")      tokenFile = configDir() + "/openai_token.txt";
        else if (m_aiProvider == "mistral")     tokenFile = configDir() + "/mistral_token.txt";
        else if (m_aiProvider == "huggingface") tokenFile = configDir() + "/huggingface_token.txt";
        else                                    tokenFile = configDir() + "/token.txt";

        QFile tf(tokenFile);
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            emit aiStatusResult(false, tr("Token file not found"));
            return;
        }
        QString apiKey = QString::fromUtf8(tf.readAll()).trimmed();
        tf.close();

        if (apiKey.isEmpty()) {
            emit aiStatusResult(false, tr("Token is empty"));
            return;
        }

        // Build request
        QNetworkRequest req;
        QByteArray postData;

        if (isGemini) {
            model = m_aiModel.isEmpty() ? "gemini-2.5-flash" : m_aiModel;
            req.setUrl(QUrl(QString(
                                "https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent?key=%2"
                                ).arg(model, apiKey)));

            QJsonObject part;  part["text"] = "Hi";
            QJsonObject cont;  cont["role"] = "user"; cont["parts"] = QJsonArray{part};
            QJsonObject cfg;   cfg["maxOutputTokens"] = 5;
            QJsonObject body;  body["contents"] = QJsonArray{cont}; body["generationConfig"] = cfg;
            postData = QJsonDocument(body).toJson(QJsonDocument::Compact);
        } else {
            if      (m_aiProvider == "openai")      urlStr = "https://api.openai.com/v1/chat/completions";
            else if (m_aiProvider == "mistral")     urlStr = "https://api.mistral.ai/v1/chat/completions";
            else if (m_aiProvider == "huggingface") urlStr = "https://api-inference.huggingface.co/v1/chat/completions";
            else                                    urlStr = "https://openrouter.ai/api/v1/chat/completions";

            if      (m_aiProvider == "openai")      model = m_aiModel.isEmpty() ? "gpt-4o-mini" : m_aiModel;
            else if (m_aiProvider == "mistral")     model = m_aiModel.isEmpty() ? "mistral-small-latest" : m_aiModel;
            else if (m_aiProvider == "huggingface") model = m_aiModel.isEmpty() ? "meta-llama/Llama-3.2-3B-Instruct" : m_aiModel;
            else                                    model = m_aiModel.isEmpty() ? "google/gemma-3-4b-it:free" : m_aiModel;

            req.setUrl(QUrl(urlStr));
            req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

            QJsonArray msgs;
            QJsonObject u; u["role"] = "user"; u["content"] = "Hi"; msgs.append(u);
            QJsonObject body; body["model"] = model; body["max_tokens"] = 5; body["messages"] = msgs;
            postData = QJsonDocument(body).toJson(QJsonDocument::Compact);
        }

        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

        QNetworkReply *reply = m_networkManager->post(req, postData);

        // Timeout 20 seconds
        QTimer *timer = new QTimer(this);
        timer->setSingleShot(true);
        timer->setInterval(6000);
        connect(timer, &QTimer::timeout, this, [this, reply, timer]() {
            timer->deleteLater();
            reply->abort();
            emit aiStatusResult(false, tr("Request timed out (6s)"));
        });
        timer->start();

        connect(reply, &QNetworkReply::finished, this, [this, reply, timer]() {
            timer->stop();
            timer->deleteLater();
            reply->deleteLater();

            int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

            if (reply->error() == QNetworkReply::OperationCanceledError) return; // timeout already triggered

            if (status >= 200 && status < 300) {
                emit aiStatusResult(true, tr(""));
            } else if (status == 401 || status == 403) {
                emit aiStatusResult(false, tr("Invalid API key (401/403)"));
            } else if (status == 429) {
                emit aiStatusResult(false, tr("Rate limit exceeded (429)"));
            } else if (status == 402) {
                emit aiStatusResult(false, tr("Payment required (402)"));
            } else if (status > 0) {
                emit aiStatusResult(false, QString("HTTP %1").arg(status));
            } else {
                emit aiStatusResult(false, reply->errorString());
            }
        });
    }

    // ─────────────────────────────────────────
    //  installFlatpak
    // ─────────────────────────────────────────
    // In installFlatpak — distinguish between .flatpakref and .flatpak
    void installFlatpak(const QString &location)
    {
        QProcess checkFlatpak;
        checkFlatpak.start("which", {"flatpak"});
        checkFlatpak.waitForFinished(3000);
        if (checkFlatpak.exitCode() != 0) {
            emitLog("flatpak is not installed on this system", orange());
            m_pendingFlatpakLocation = location;
            emit askInstallFlatpak();
            return;
        }

        bool isBundleFile = location.endsWith(".flatpak", Qt::CaseInsensitive);

        QString appId;
        // NEW CODE:
        if (isBundleFile) {
            // .flatpak bundle — is an OSTree repository, not a ZIP
            // Extract appId via ostree refs
            QProcess query1;
            query1.start("sh", {"-c",
                                QString("ostree refs --repo '%1' 2>/dev/null | grep '^app/' | head -1 | cut -d/ -f2")
                                    .arg(location)});
            query1.waitForFinished(5000);
            appId = QString::fromUtf8(query1.readAllStandardOutput()).trimmed();

            // Fallback: via flatpak bundle-info (newer flatpak versions)
            if (appId.isEmpty()) {
                QProcess query2;
                query2.start("sh", {"-c",
                                    QString("flatpak bundle-info '%1' 2>/dev/null | grep '^Ref:' | "
                                            "sed 's|.*app/||;s|/.*||'").arg(location)});
                query2.waitForFinished(5000);
                appId = QString::fromUtf8(query2.readAllStandardOutput()).trimmed();
            }

            // Another option: via filename as last fallback
            // ElyPrismLauncher-Linux-9.5-Flatpak-x86_64.flatpak → will try from installed later
            emitLog("Flatpak Bundle App ID: " + (appId.isEmpty() ? "(unknown)" : appId));
        } else {
            appId = readFlatpakrefAppId(location);
            emitLog("Flatpak App ID: " + (appId.isEmpty() ? "(unknown)" : appId));
        }

        if (!appId.isEmpty()) {
            QProcess checkInstalled;
            checkInstalled.start("flatpak", {"list", "--app", "--columns=application"});
            checkInstalled.waitForFinished(5000);
            QString installedList = QString::fromUtf8(checkInstalled.readAllStandardOutput());
            for (const QString &line : installedList.split('\n')) {
                if (line.trimmed() == appId) {
                    emitLog("Flatpak package \"" + appId + "\" is already installed", orange());
                    m_pendingFlatpakLocation = location;
                    m_pendingFlatpakAppId    = appId;
                    emit askReinstallFlatpak(appId);
                    return;
                }
            }
        }

        m_pendingFlatpakAppId = appId;  // ← save in advance!
        m_pendingFlatpakIsBundle = isBundleFile;
        m_flatpakPhase = FlatpakPhase::Idle;
        setInstallProgress(8);

        QFileSystemWatcher *flatpakWatcher = new QFileSystemWatcher(this);
        flatpakWatcher->addPath(QDir::homePath() + "/.cache");

        if (isBundleFile)
            runHelperAsync("install-flatpak-bundle", {location});
        else
            runHelperAsync("install-flatpak", {location});
    }

    QString readFlatpakrefAppId(const QString &location)
    {
        QFile f(location);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
            return QString();

        QString appId;
        while (!f.atEnd()) {
            QString line = QString::fromUtf8(f.readLine()).trimmed();
            if (line.startsWith("Name=")) {
                appId = line.mid(5).trimmed();
                break;
            }
        }
        return appId;
    }

    Q_INVOKABLE void resetExecCommand()
    {
        m_execCommandCustomized = false;
        buildDefaultExecCommand();
    }

    static std::chrono::high_resolution_clock::time_point getStartTime() {
        static auto start = std::chrono::high_resolution_clock::now();
        return start;
    }

    Q_INVOKABLE void confirmReinstallFlatpak(bool reinstall)
    {
        if (!reinstall) {
            emitLog("Reinstall cancelled" "red");
            emit hideKillPacmanButton();
            m_pendingFlatpakLocation = "";
            m_pendingFlatpakAppId    = "";
            return;
        }


        emitLog("Removing existing Flatpak package: " + m_pendingFlatpakAppId + "...");

        QProcess *removeProc = new QProcess(this);
        connect(removeProc, &QProcess::readyReadStandardOutput, this, [this, removeProc]() {
            emitLog(stripAnsi(QString::fromUtf8(removeProc->readAllStandardOutput()).trimmed()));
        });
        connect(removeProc, &QProcess::readyReadStandardError, this, [this, removeProc]() {
            QString err = stripAnsi(QString::fromUtf8(removeProc->readAllStandardError()).trimmed());
            if (!err.isEmpty()) emitLog(err, greycolor());
        });
        connect(removeProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, removeProc](int exitCode, QProcess::ExitStatus status) {
                    removeProc->deleteLater();
                    if (status != QProcess::NormalExit || exitCode != 0) {
                        emitLog("Failed to remove Flatpak package", "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                        m_pendingFlatpakLocation = "";
                        m_pendingFlatpakAppId    = "";
                        return;
                    }
                    emitLog("Flatpak package removed successfully", greencolor());

                    QString loc = m_pendingFlatpakLocation;
                    bool wasBundle = m_pendingFlatpakIsBundle;
                    QString savedAppId = m_pendingFlatpakAppId;
                    m_pendingFlatpakLocation = "";
                    m_pendingFlatpakAppId    = "";
                    m_pendingFlatpakAppId = savedAppId;
                    if (wasBundle)
                        runHelperAsync("install-flatpak-bundle", {loc});
                    else
                        runHelperAsync("install-flatpak", {loc});
                });

        removeProc->start("flatpak", {"uninstall", "--noninteractive", m_pendingFlatpakAppId});
    }

    // ─────────────────────────────────────────
    //  confirmAppimageInstall
    // ─────────────────────────────────────────
    Q_INVOKABLE void confirmAppimageInstall(const QString &name,
                                            const QString &description,
                                            const QString &category,
                                            const QString &customIconPath)
    {
        emitLog("Building Arch package from AppImage...");
        emit showKillPacmanButton();
        setInstallProgress(8);

        const QString location = m_appimageLocation;
        QString pkgNameLower   = name.toLower().replace(" ", "-");
        const QString version  = "1.0.0";
        const QString arch     = "x86_64";

        QString desc = description.isEmpty() ? name + " AppImage" : description;
        desc.replace("'", "").replace("\"", "");

        QString desktopCategories = category.isEmpty() ? "Utility;" : category;
        if (!desktopCategories.endsWith(";")) desktopCategories += ";";

        QString buildDir = QString::fromStdString(string(getenv("HOME")))
                           + "/.cache/PackageInstaller-build";

        QString iconSetupScript;
        if (!customIconPath.isEmpty() && QFileInfo::exists(customIconPath)) {
            iconSetupScript =
                "cp \"" + customIconPath + "\" \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n";
        } else {
            iconSetupScript =
                "SYSICON=$(find /usr/share/icons -name 'application-x-executable.png' 2>/dev/null | head -1)\n"
                "if [ -n \"$SYSICON\" ]; then\n"
                "    cp \"$SYSICON\" \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n"
                "else\n"
                "    touch \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n"
                "fi\n";
        }

        QString script =
            "set -e\n"
            "PKGNAME=\""    + pkgNameLower      + "\"\n"
                             "VERSION=\""    + version           + "\"\n"
                        "ARCH=\""       + arch              + "\"\n"
                     "APPIMAGE=\""   + location          + "\"\n"
                         "APPNAME=\""    + name              + "\"\n"
                     "APPDESC=\""    + desc              + "\"\n"
                     "CATEGORIES=\"" + desktopCategories + "\"\n"
                                  "BUILDDIR=\""   + buildDir          + "\"\n"
                         "\n"
                         "rm -rf \"$BUILDDIR\"\n"
                         "mkdir -p \"$BUILDDIR/pkg/usr/bin\"\n"
                         "mkdir -p \"$BUILDDIR/pkg/usr/share/applications\"\n"
                         "mkdir -p \"$BUILDDIR/pkg/usr/share/pixmaps\"\n"
                         "\n"
                         "cp \"$APPIMAGE\" \"$BUILDDIR/pkg/usr/bin/$PKGNAME\"\n"
                         "chmod +x \"$BUILDDIR/pkg/usr/bin/$PKGNAME\"\n"
                         "\n"
            + iconSetupScript +
            "\n"
            "printf '[Desktop Entry]\\nName=%s\\nComment=%s\\nExec=/usr/bin/%s\\n"
            "Icon=%s\\nType=Application\\nCategories=%s\\nTerminal=false\\nX-KDE-StartupNotify=false\\n' \\\n"
            "    \"$APPNAME\" \"$APPDESC\" \"$PKGNAME\" \"$PKGNAME\" \"$CATEGORIES\" \\\n"
            "    > \"$BUILDDIR/pkg/usr/share/applications/$PKGNAME.desktop\"\n"
            "echo '--- .desktop ---'\n"
            "cat \"$BUILDDIR/pkg/usr/share/applications/$PKGNAME.desktop\"\n"
            "\n"
            "INSTALLED_SIZE=$(du -sb \"$BUILDDIR/pkg\" | cut -f1)\n"
            "BUILDDATE=$(date +%s)\n"
            "printf '# Generated by PackageInstaller\\npkgname = %s\\npkgver = %s-1\\n"
            "arch = %s\\nsize = %s\\npkgdesc = %s\\nbuilddate = %s\\npackager = PackageInstaller\\n' \\\n"
            "    \"$PKGNAME\" \"$VERSION\" \"$ARCH\" \"$INSTALLED_SIZE\" \"$APPDESC\" \"$BUILDDATE\" \\\n"
            "    > \"$BUILDDIR/pkg/.PKGINFO\"\n"
            "\n"
            "cd \"$BUILDDIR/pkg\"\n"
            "bsdtar -czf .MTREE --format=mtree \\\n"
            "    --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' \\\n"
            "    usr 2>/dev/null || {\n"
            "    printf '\\x1f\\x8b\\x08\\x00\\x00\\x00\\x00\\x00\\x00\\x03\\x03\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00' > .MTREE\n"
            "}\n"
            "\n"
            "PKGFILE=\"$BUILDDIR/${PKGNAME}-${VERSION}-1-${ARCH}.pkg.tar.zst\"\n"
            "{\n"
            "    ls -1 .PKGINFO .MTREE 2>/dev/null\n"
            "    find usr -mindepth 1 | sort\n"
            "} > \"$BUILDDIR/filelist.txt\"\n"
            "bsdtar --zstd -cf \"$PKGFILE\" -T \"$BUILDDIR/filelist.txt\"\n"
            "echo '--- pacman -Qp check:'\n"
            "pacman -Qp \"$PKGFILE\"\n"
            "echo \"PKGFILE=$PKGFILE\"\n";

        QProcess *proc = new QProcess(this);
        connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc]() {
            emitLog(stripAnsi(QString::fromUtf8(proc->readAllStandardOutput()).trimmed()));
        });
        connect(proc, &QProcess::readyReadStandardError, this, [this, proc]() {
            QString err = stripAnsi(QString::fromUtf8(proc->readAllStandardError()).trimmed());
            if (!err.isEmpty()) emitLog(err, greycolor());
        });
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc, buildDir, pkgNameLower, version, arch](int exitCode, QProcess::ExitStatus status) {
                    proc->deleteLater();
                    if (status != QProcess::NormalExit || exitCode != 0) {
                        emitLog("AppImage packaging failed", "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                        return;
                    }
                    QString pkgFile = buildDir + "/" + pkgNameLower + "-" + version + "-1-" + arch + ".pkg.tar.zst";
                    if (!QFileInfo::exists(pkgFile)) {
                        emitLog("Package file not found", "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                        return;
                    }
                    emitLog("AppImage packaged: " + pkgFile, greencolor());
                    setInstallProgress(68);
                    installArchPkg(pkgFile);
                });

        setInstallProgress(36);
        proc->start("/bin/bash", {"-c", script});
    }

    // ─────────────────────────────────────────
    //  installPackage — called from QML
    // ─────────────────────────────────────────
    Q_INVOKABLE void installPackage()
    {
        if (m_appName.isEmpty()) {
            emitLog("Missing app name", "red");
            emit showErrorDialog();
            return;
        }
        if (m_executable.isEmpty()) {
            emit showNoExecutableError();
            return;
        }

        emit showKillPacmanButton();

        if (m_packageType == "tarboll") {
            setInstallProgress(54);
        } else if (m_packageType == "dir") {
            setInstallProgress(54);
        } else {
            setInstallProgress(8);
        }

        std::string extractedDir = getExtractedDir().toStdString();
        std::string rootDir      = normalizeExtractedDir(extractedDir);

        QString qRootDir     = QString::fromStdString(rootDir);
        QString execFileName = QFileInfo(m_executable).fileName();
        QString execRelPath = m_executable;
        if (execRelPath.startsWith(qRootDir))
            execRelPath = execRelPath.mid(qRootDir.length());
        if (execRelPath.startsWith("/"))
            execRelPath = execRelPath.mid(1);
        QString iconFileName = QFileInfo(m_iconPath).fileName();

        QString pkgNameLower = m_appName.toLower().replace(" ", "-");
        const QString version = "1.0.0";
        const QString arch    = "x86_64";

        QString desktopCategories = m_appCategory.isEmpty() ? "Utility;" : m_appCategory;
        if (!desktopCategories.endsWith(";")) desktopCategories += ";";

        QString description = m_appDescription.isEmpty()
                                  ? m_appName + " (installed from archive)"
                                  : m_appDescription;
        description.replace("'", "").replace("\"", "");

        QString execCmd = m_execCommand.trimmed();
        if (execCmd.isEmpty()) {
            execCmd = "/usr/bin/" + pkgNameLower;
        }
        QString execCmdEscaped = execCmd;
        execCmdEscaped.replace("\\", "\\\\").replace("\"", "\\\"");

        QString buildDir = QString::fromStdString(string(getenv("HOME")))
                           + "/.cache/PackageInstaller-build";

        emitLog("Building Arch package from archive...");

        bool iconIsExternal = !m_iconPath.isEmpty() && !m_iconPath.startsWith(qRootDir);
        QString iconCopyScript;
        if (!m_iconPath.isEmpty() && iconIsExternal) {
            iconCopyScript =
                "cp \"" + m_iconPath + "\" \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n";
        } else if (!m_iconPath.isEmpty()) {
            iconCopyScript =
                "ICONPATH=$(find \"$BUILDDIR/pkg/usr/lib/$PKGNAME\" -name \"" + iconFileName + "\" 2>/dev/null | head -1)\n"
                                                                                               "if [ -n \"$ICONPATH\" ]; then\n"
                                                                                               "    cp \"$ICONPATH\" \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n"
                                                                                               "else\n"
                                                                                               "    SYSICON=$(find /usr/share/icons -name 'application-x-executable.png' 2>/dev/null | head -1)\n"
                                                                                               "    if [ -n \"$SYSICON\" ]; then\n"
                                                                                               "        cp \"$SYSICON\" \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n"
                                                                                               "    else\n"
                                                                                               "        touch \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n"
                                                                                               "    fi\n"
                                                                                               "fi\n";
        } else {
            iconCopyScript =
                "SYSICON=$(find /usr/share/icons -name 'application-x-executable.png' 2>/dev/null | head -1)\n"
                "if [ -n \"$SYSICON\" ]; then\n"
                "    cp \"$SYSICON\" \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n"
                "else\n"
                "    touch \"$BUILDDIR/pkg/usr/share/pixmaps/$PKGNAME.png\"\n"
                "fi\n";
        }

        bool execIsExternal = !m_executable.startsWith(qRootDir);
        QString execSetupScript;
        if (execIsExternal) {
            execSetupScript =
                "chmod +x \"$BUILDDIR/pkg/usr/lib/$PKGNAME/$EXECFILE\"\n"
                "ln -sf \"/usr/lib/$PKGNAME/$EXECFILE\" \"$BUILDDIR/pkg/usr/bin/$PKGNAME\"\n";
        } else {
            execSetupScript =
                "chmod +x \"$BUILDDIR/pkg/usr/lib/$PKGNAME/$EXECFILE\"\n"
                "ln -sf \"/usr/lib/$PKGNAME/$EXECFILE\" \"$BUILDDIR/pkg/usr/bin/$PKGNAME\"\n";
        }

        QString script =
            "set -e\n"
            "PKGNAME=\""    + pkgNameLower     + "\"\n"
                             "VERSION=\""    + version          + "\"\n"
                        "ARCH=\""       + arch             + "\"\n"
                     "ROOTDIR=\""    + qRootDir         + "\"\n"
                         "EXECFILE=\""   + execRelPath      + "\"\n"   // ← relative path
                            "EXECBASE=\""   + execFileName     + "\"\n"   // ← name only for symlink
                             "ICONFILE=\""   + iconFileName     + "\"\n"
                             "APPNAME=\""    + m_appName        + "\"\n"
                          "APPDESC=\""    + description      + "\"\n"
                            "CATEGORIES=\"" + desktopCategories+ "\"\n"
                                  "EXECCMD=\""    + execCmdEscaped   + "\"\n"
                               "BUILDDIR=\""   + buildDir         + "\"\n"
                         "\n"
                         "rm -rf \"$BUILDDIR\"\n"
                         "mkdir -p \"$BUILDDIR/pkg/usr/bin\"\n"
                         "mkdir -p \"$BUILDDIR/pkg/usr/share/pixmaps\"\n"
                         "mkdir -p \"$BUILDDIR/pkg/usr/share/applications\"\n"
                         "mkdir -p \"$BUILDDIR/pkg/usr/lib/$PKGNAME\"\n"
                         "\n"
                         "cp -r \"$ROOTDIR\"/. \"$BUILDDIR/pkg/usr/lib/$PKGNAME/\"\n"
                         "\n"
            + execSetupScript +
            "\n"
            + iconCopyScript +
            "\n"
            "printf '[Desktop Entry]\\nName=%s\\nComment=%s\\nExec=%s\\n"
            "Icon=%s\\nType=Application\\nCategories=%s\\nTerminal=false\\nX-KDE-StartupNotify=false\\n' \\\n"
            "    \"$APPNAME\" \"$APPDESC\" \"$EXECCMD\" \"$PKGNAME\" \"$CATEGORIES\" \\\n"
            "    > \"$BUILDDIR/pkg/usr/share/applications/$PKGNAME.desktop\"\n"
            "echo '--- .desktop ---'\n"
            "cat \"$BUILDDIR/pkg/usr/share/applications/$PKGNAME.desktop\"\n"
            "\n"
            "INSTALLED_SIZE=$(du -sb \"$BUILDDIR/pkg\" | cut -f1)\n"
            "BUILDDATE=$(date +%s)\n"
            "\n"
            "printf '# Generated by PackageInstaller\\npkgname = %s\\npkgver = %s-1\\n"
            "arch = %s\\nsize = %s\\npkgdesc = %s\\nbuilddate = %s\\npackager = PackageInstaller\\n' \\\n"
            "    \"$PKGNAME\" \"$VERSION\" \"$ARCH\" \"$INSTALLED_SIZE\" \"$APPDESC\" \"$BUILDDATE\" \\\n"
            "    > \"$BUILDDIR/pkg/.PKGINFO\"\n"
            "echo '--- .PKGINFO ---'\n"
            "cat \"$BUILDDIR/pkg/.PKGINFO\"\n"
            "\n"
            "cd \"$BUILDDIR/pkg\"\n"
            "bsdtar -czf .MTREE --format=mtree \\\n"
            "    --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' \\\n"
            "    usr 2>/dev/null || {\n"
            "    echo 'bsdtar mtree failed, creating empty .MTREE'\n"
            "    printf '\\x1f\\x8b\\x08\\x00\\x00\\x00\\x00\\x00\\x00\\x03\\x03\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00' > .MTREE\n"
            "}\n"
            "\n"
            "PKGFILE=\"$BUILDDIR/${PKGNAME}-${VERSION}-1-${ARCH}.pkg.tar.zst\"\n"
            "cd \"$BUILDDIR/pkg\"\n"
            "{\n"
            "    ls -1 .PKGINFO .MTREE 2>/dev/null\n"
            "    find usr -mindepth 1 | sort\n"
            "} > \"$BUILDDIR/filelist.txt\"\n"
            "echo '--- file list (first 10):'\n"
            "head -10 \"$BUILDDIR/filelist.txt\"\n"
            "bsdtar --zstd -cf \"$PKGFILE\" -T \"$BUILDDIR/filelist.txt\"\n"
            "\n"
            "echo '--- pacman -Qp check:'\n"
            "pacman -Qp \"$PKGFILE\"\n"
            "echo '---'\n"
            "echo \"PKGFILE=$PKGFILE\"\n";

        QProcess *buildProc = new QProcess(this);
        connect(buildProc, &QProcess::readyReadStandardOutput, this, [this, buildProc]() {
            QString out = stripAnsi(QString::fromUtf8(buildProc->readAllStandardOutput()).trimmed());
            if (!out.isEmpty()) emitLog(out);
        });
        connect(buildProc, &QProcess::readyReadStandardError, this, [this, buildProc]() {
            QString err = stripAnsi(QString::fromUtf8(buildProc->readAllStandardError()).trimmed());
            if (!err.isEmpty()) emitLog(err, greycolor());
        });
        connect(buildProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, buildProc, buildDir, pkgNameLower, version, arch]
                (int exitCode, QProcess::ExitStatus status)
                {
                    buildProc->deleteLater();
                    if (status != QProcess::NormalExit || exitCode != 0) {
                        emitLog("Package build failed (exit " + QString::number(exitCode) + ")", "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                        return;
                    }
                    QString pkgFile = buildDir + "/" + pkgNameLower
                                      + "-" + version + "-1-" + arch + ".pkg.tar.zst";
                    if (!QFileInfo::exists(pkgFile)) {
                        emitLog("Built package file not found: " + pkgFile, "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                        return;
                    }
                    emitLog("Package assembled: " + pkgFile, greencolor());
                    installArchPkg(pkgFile);
                });

        buildProc->start("/bin/bash", {"-c", script});
    }

    Q_INVOKABLE void killPacman()
    {
        m_cancelledByUser = true;

        QProcess check;
        check.start("/bin/sh", {"-c",
            "pgrep -x pacman || pgrep -x flatpak"});
        check.waitForFinished(1000);

        if (check.exitCode() == 0) {
            runHelperSync("kill-pacman", {});
        }

        emitLog("Installation process killed by user", "red");
    }

    Q_INVOKABLE QString loadHuggingFaceToken() const {
        QFile f(configDir() + "/huggingface_token.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }
    Q_INVOKABLE bool saveHuggingFaceToken(const QString &token) {
        QFile f(configDir() + "/huggingface_token.txt");
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) return false;
        f.write(token.toUtf8()); f.close();
        saveDebNoAiWarningDisabled(false);
        saveRpmNoAiWarningDisabled(false);
        emit hasHuggingFaceTokenChanged();
        return true;
    }
    // AFTER saveOpenAiToken(...) block add:

    Q_INVOKABLE QString loadMistralToken() const {
        QFile f(configDir() + "/mistral_token.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }

    Q_INVOKABLE QString loadProviderModel(const QString &provider) const {
        QFile f(configDir() + "/ai_model_" + provider + ".txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }

    Q_INVOKABLE bool saveProviderModel(const QString &provider, const QString &model) {
        QFile f(configDir() + "/ai_model_" + provider + ".txt");
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) return false;
        f.write(model.toUtf8());
        f.close();
        return true;
    }

    Q_INVOKABLE bool saveMistralToken(const QString &token) {
        QFile f(configDir() + "/mistral_token.txt");
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) return false;
        saveDebNoAiWarningDisabled(false);
        saveRpmNoAiWarningDisabled(false);
        f.write(token.toUtf8()); f.close();
        emit hasMistralTokenChanged();
        return true;
    }
    Q_INVOKABLE QString loadOpenAiToken() const {
        QFile f(configDir() + "/openai_token.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }
    Q_INVOKABLE bool saveOpenAiToken(const QString &token) {
        QFile f(configDir() + "/openai_token.txt");
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) return false;
        saveDebNoAiWarningDisabled(false);
        saveRpmNoAiWarningDisabled(false);
        f.write(token.toUtf8()); f.close();
        emit hasOpenAiTokenChanged();
        return true;
    }

    Q_INVOKABLE void reinstallAPP(const QString &pkgName, const QString &location)
    {
        emitLog("Reinstalling " + pkgName);
        emit showKillPacmanButton();

        QProcess *process = new QProcess(this);
        connect(process, &QProcess::readyReadStandardOutput, this, [this, process]() {
            emitLog(stripAnsi(QString::fromUtf8(process->readAllStandardOutput()).trimmed()));
        });
        connect(process, &QProcess::readyReadStandardError, this, [this, process]() {
            emitLog(stripAnsi(QString::fromUtf8(process->readAllStandardError()).trimmed()), "red");
        });
        connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, location, process](int exitCode, QProcess::ExitStatus status) {
                    process->deleteLater();
                    if (status == QProcess::NormalExit && exitCode == 0) {
                        emitLog("Package removed successfully", greencolor());
                        runHelperAsync("install-pkg", {location});
                    } else {
                        emitLog("Removal failed with code " + QString::number(exitCode), "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                    }
                });

        process->start("pkexec", {helperPath(), "remove-pkg", pkgName});
    }


    Q_INVOKABLE void cancel()
    {
        m_cancelledByUser = true;

        if (m_flatpakPhase != FlatpakPhase::Idle) {
            m_flatpakPhase = FlatpakPhase::Idle;
        }

        QProcess check;
        check.start("/bin/sh", {"-c",
            "pgrep -x pacman || pgrep -x flatpak"});
        check.waitForFinished(1000);

        if (check.exitCode() == 0) {
            runHelperSync("kill-pacman", {});
        }

        rmAlltempfiles();
        emitLog("Canceled by user", "red");
        emit hideKillPacmanButton();
    }

    Q_INVOKABLE QStringList findExecutables(const QString &rootDir, const QString &archivePath)
    {
        QStringList executables;
        string root = rootDir.toStdString();
        QString archiveName = archiveBaseName(archivePath);

        for (const auto &entry : filesystem::recursive_directory_iterator(root)) {
            if (!entry.is_regular_file()) continue;
            QString path = QString::fromStdString(entry.path().string());

            QString fileName = QFileInfo(path).fileName();
            if (fileName.contains('.')) continue;

            struct stat st;
            if (stat(entry.path().string().c_str(), &st) != 0) continue;
            if (!(st.st_mode & S_IXUSR)) continue;

            executables.append(path);
        }

        std::sort(executables.begin(), executables.end(),
                  [this, &archiveName](const QString &a, const QString &b) {
                      int sA = similarityScore(execBaseName(a), archiveName);
                      int sB = similarityScore(execBaseName(b), archiveName);
                      if (sA != sB) return sA > sB;
                      int lA = QFileInfo(a).fileName().length();
                      int lB = QFileInfo(b).fileName().length();
                      if (lA != lB) return lA < lB;
                      return a < b;
                  });
        return executables;
    }

    Q_INVOKABLE void copyToClipboard(const QString &text) {
        QGuiApplication::clipboard()->setText(text);
    }

    Q_INVOKABLE QStringList findIcons(const QString &rootDir)
    {
        QStringList icons;
        for (const auto &entry : filesystem::recursive_directory_iterator(rootDir.toStdString())) {
            if (!entry.is_regular_file()) continue;
            QString path = QString::fromStdString(entry.path().string());
            if (path.endsWith(".ico") || path.endsWith(".png") ||
                path.endsWith(".jpg") || path.endsWith(".jpeg") || path.endsWith(".svg"))
                icons.append(path);
        }
        std::sort(icons.begin(), icons.end(), [](const QString &a, const QString &b) {
            bool dA = std::any_of(a.begin(), a.end(), [](QChar c){ return c.isDigit(); });
            bool dB = std::any_of(b.begin(), b.end(), [](QChar c){ return c.isDigit(); });
            if (dA && dB) { bool h64A = a.contains("64"); bool h64B = b.contains("64"); if (h64A != h64B) return h64A; return a < b; }
            if (dA != dB) return dA;
            return a < b;
        });
        return icons;
    }

    // ─── Asynchronous versions for QML ──────────────────────────────────────
    // QML calls these methods instead of synchronous findExecutables/findIcons.
    // Result is returned via signals executablesReady / iconsReady.

    Q_INVOKABLE void findExecutablesAsync(const QString &rootDir, const QString &archivePath)
    {
        auto *watcher = new QFutureWatcher<QStringList>(this);
        connect(watcher, &QFutureWatcher<QStringList>::finished,
                this, [this, watcher]() {
                    QStringList result = watcher->result();
                    watcher->deleteLater();
                    emit executablesReady(result);
                });
        watcher->setFuture(
            QtConcurrent::run([this, rootDir, archivePath]() {
                return findExecutables(rootDir, archivePath);
            })
            );
    }

    Q_INVOKABLE void findIconsAsync(const QString &rootDir)
    {
        auto *watcher = new QFutureWatcher<QStringList>(this);
        connect(watcher, &QFutureWatcher<QStringList>::finished,
                this, [this, watcher]() {
                    QStringList result = watcher->result();
                    watcher->deleteLater();
                    emit iconsReady(result);
                });
        watcher->setFuture(
            QtConcurrent::run([this, rootDir]() {
                return findIcons(rootDir);
            })
            );
    }

    Q_INVOKABLE QString loadToken() const
    {
        QFile f(configDir() + "/token.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }

    // ─────────────────────────────────────────
    //  saveToken — saves token to file
    // ─────────────────────────────────────────
    Q_INVOKABLE bool saveToken(const QString &token)
    {
        QFile f(configDir() + "/token.txt");
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
            return false;
        f.write(token.toUtf8());
        f.close();
        saveDebNoAiWarningDisabled(false);
        saveRpmNoAiWarningDisabled(false);
        emit hasTokenChanged();
        return true;
    }

    Q_INVOKABLE QString loadGeminiToken() const
    {
        QFile f(configDir() + "/gemini_token.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }

    Q_INVOKABLE bool saveGeminiToken(const QString &token)
    {
        QFile f(configDir() + "/gemini_token.txt");
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
            return false;
        f.write(token.toUtf8());
        f.close();
        saveDebNoAiWarningDisabled(false);
        saveRpmNoAiWarningDisabled(false);
        emit hasGeminiTokenChanged();
        return true;
    }

    // ─────────────────────────────────────────
    //  archPackageListDate — date of the arch-packages.txt file
    // ─────────────────────────────────────────
    Q_INVOKABLE QString archPackageListDate() const
    {
        QFileInfo fi(configDir() + "/arch-packages.txt");
        if (!fi.exists()) return QObject::tr("Not generated yet");
        return QObject::tr("Last updated: ") + fi.lastModified().toString("yyyy-MM-dd hh:mm");
    }

    // ─────────────────────────────────────────
    //  forceUpdateArchPackageList — forcibly updates the list
    // ─────────────────────────────────────────
    Q_INVOKABLE void forceUpdateArchPackageList()
    {
        if (m_updatingPackageList) return;
        m_updatingPackageList = true;
        emit updatingPackageListChanged();

        QString outputFile = configDir() + "/arch-packages.txt";

        emitLog(tr("Updating Arch package list..."), greycolor());

        QProcess *gen = new QProcess(this);
        connect(gen, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, gen, outputFile](int exitCode, QProcess::ExitStatus) {
                    gen->deleteLater();
                    m_updatingPackageList = false;
                    emit updatingPackageListChanged();
                    if (QFileInfo::exists(outputFile) && QFileInfo(outputFile).size() > 0) {
                        emit archPackageListDateChanged();
                        m_archsuccess = true;
                        emit archsuccessChanged();
                    } else {
                        emitLog(tr("Failed to update Arch package list (exit ") + QString::number(exitCode) + ")", "red");
                        m_archerror = true;
                        emit archerrorChanged();
                    }
                });
        gen->start("/bin/bash", {"-c", "pacman -Sl | awk '{print $2}' > " + outputFile});
    }

    bool updatingPackageList() const { return m_updatingPackageList; }

    // ─────────────────────────────────────────
    //  availableLanguages — scans the file system and resources
    // ─────────────────────────────────────────
    Q_INVOKABLE QVariantList availableLanguages() const
    {
        QVariantList result;
        QStringList allFiles;

        // 1. Scanning the file system
        QStringList transDirs = {
            "/opt/packageinstaller/translations",
            QCoreApplication::applicationDirPath() + "/translations",
            "translations"
        };
        for (const QString &td : transDirs) {
            QDir dir(td);
            if (dir.exists()) {
                QStringList fsFiles = dir.entryList({"packageinstaller_*.qm"}, QDir::Files);
                for (const QString &f : fsFiles) {
                    if (!allFiles.contains(f)) allFiles.append(f);
                }
            }
        }

        // 2. Scanning resources (:/i18n)
        QDir resDir(":/i18n");
        if (resDir.exists()) {
            QStringList resFiles = resDir.entryList({"packageinstaller_*.qm"}, QDir::Files);
            for (const QString &f : resFiles) {
                if (!allFiles.contains(f)) allFiles.append(f);
            }
        }

        if (allFiles.isEmpty()) return result;

        QStringList processedCodes;
        for (const QString &file : allFiles) {
            QString code = file;
            code.remove("packageinstaller_");
            code.remove(".qm");
            if (code.isEmpty() || processedCodes.contains(code)) continue;
            processedCodes.append(code);

            QLocale locale(code);
            QString displayName = locale.nativeLanguageName();
            if (displayName.isEmpty()) displayName = code;
            // Capitalize the first letter
            if (!displayName.isEmpty()) displayName[0] = displayName[0].toUpper();

            QVariantMap entry;
            entry["code"]    = code;
            entry["display"] = displayName;
            result.append(entry);
        }
        return result;
    }

    // ─────────────────────────────────────────
    //  currentLanguage — returns the saved language code
    // ─────────────────────────────────────────
    Q_INVOKABLE QString currentLanguage() const
    {
        QFile f(configDir() + "/language.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }

    // ─────────────────────────────────────────
    //  setLanguage — saves the language choice
    //  Actual translation loading — at startup in main()
    // ─────────────────────────────────────────
    // Replacing setLanguage method
    Q_INVOKABLE void setLanguage(const QString &code)
    {
        QFile f(configDir() + "/language.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(code.toUtf8());
            f.close();
        }

        if (g_translator) {
            qApp->removeTranslator(g_translator);
            delete g_translator;
            g_translator = new QTranslator(qApp);
        }

        if (loadTranslator(g_translator, code)) {
            qApp->installTranslator(g_translator);
        }

        emit askReloadUi();
    }

    Q_INVOKABLE void regenerateAppimageDescription()
    {
        if (!m_hasAiAccess) return;
        analyzeAppimageWithAI(m_appimageLocation);
    }

    Q_INVOKABLE void resetAppimageDescriptionToFirst()
    {
        if (m_aiFirstAppimageDescription.isEmpty()) return;
        m_aiAppDescription = "";
        setAiAppDescription(m_aiFirstAppimageDescription);
    }

    Q_INVOKABLE bool copyDirectory(const QString &sourceDir, const QString &destDir) {
        QDir src(sourceDir);
        if (!src.exists()) return false;
        QDir().mkpath(destDir);
        for (const QString &fileName : src.entryList(QDir::Files)) {
            QFile::copy(sourceDir + "/" + fileName, destDir + "/" + fileName);
        }
        for (const QString &dirName : src.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            copyDirectory(sourceDir + "/" + dirName, destDir + "/" + dirName);
        }
        return true;
    }


    Q_INVOKABLE void saveDepsEditResult(const QVariantList &deps) {
        QJsonArray arr;
        for (const QVariant &item : deps) {
            QVariantMap map = item.toMap();
            QJsonObject obj;
            obj["key"]   = map["key"].toString();
            obj["value"] = map["value"].toString();
            arr.append(obj);
        }
        QString path = configDir() + "/deps_edit_result.json";
        QFile f(path);
        if (f.open(QIODevice::WriteOnly)) {
            f.write(QJsonDocument(arr).toJson());
        }
    }

    Q_INVOKABLE bool isDependenciesSwitch() {
        return loadDependenciesSwitch();
    }

    Q_INVOKABLE bool loadAutostartEnabled() const {
        QString path = QDir::homePath() + "/.config/autostart/PackageInstaller.desktop";
        return QFileInfo::exists(path);
    }

    Q_INVOKABLE void saveAutostartEnabled(bool val) {
        QString autostartPath = QDir::homePath() + "/.config/autostart/PackageInstaller.desktop";

        if (!val) {
            QFile::remove(autostartPath);
            if (g_trayIcon) g_trayIcon->hide();
            emit autostartChanged(false);
            return;
        }

        QDir().mkpath(QDir::homePath() + "/.config/autostart");
        QFile f(autostartPath);
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(QString(
                        "[Desktop Entry]\n"
                        "Type=Application\n"
                        "Name=Linux App Installer\n"
                        "Exec=%1 --tray\n"          // ← always --tray
                        "Hidden=false\n"
                        "NoDisplay=false\n"
                        "X-GNOME-Autostart-enabled=true\n"
                        ).arg(QCoreApplication::applicationFilePath()).toUtf8());
            f.close();
        }

        // Show tray only if it exists (i.e. if it is currently trayMode)
        if (g_trayIcon) g_trayIcon->show();
        emit autostartChanged(true);
    }


    Q_INVOKABLE void runFile(const QString &filePath)
    {
        if (QFileInfo(filePath).isExecutable()) QProcess::startDetached(filePath);
        else if (filePath.endsWith(".sh")) QProcess::startDetached("konsole", {"-e", filePath});
        else QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
    }

    Q_INVOKABLE QString getExtractedDir() {
        return QString::fromStdString(string(getenv("HOME")) + "/.cache/PackageInstaller");
    }

    Q_INVOKABLE QString suggestAppName(const QString &rootDir, const QString &archivePath)
    {
        QStringList execs = findExecutables(rootDir, archivePath);
        if (execs.isEmpty()) return archiveBaseName(archivePath);
        QString best = execBaseName(execs.first());
        if (!best.isEmpty()) best[0] = best[0].toUpper();
        return best;
    }

    Q_INVOKABLE QString appimageBaseName(const QString &path)
    {
        QString name = QFileInfo(path).baseName();
        name = name.split(QRegularExpression("[-_][0-9]")).first();
        if (!name.isEmpty()) name[0] = name[0].toUpper();
        return name;
    }

    Q_INVOKABLE QString packageRootDir()
    {
        std::string extractedDir = getExtractedDir().toStdString();
        std::string rootDir      = normalizeExtractedDir(extractedDir);
        return QString::fromStdString(rootDir);
    }

signals:
    void noInternetDialog();
    void hasTrayChanged();
    void autostartChanged(bool enabled);
    void notArch();
    void showDepsEditWindow(const QJsonArray &deps);
    void requestLogReplacement(const QString &targetPart, const QString &newText);
    void updateLastLogMessage(const QString &line);
    void archerrorChanged();
    void archsuccessChanged();
    void aiStatusChecking();
    void aiStatusResult(bool ok, const QString &message);
    void showAiCustomErrorDialog(const QString &model, const QString &error, const short &status);
    void hasOpenAiTokenChanged();
    void hasMistralTokenChanged();
    void showShUnsapportedDialog();
    void notificationActionClicked();
    void hasHuggingFaceTokenChanged();
    void aiModelChanged();
    void aiProviderChanged();
    void hasGeminiTokenChanged();
    void accentOnlyColorsChanged();
    void executablesReady(const QStringList &executables);
    void iconsReady(const QStringList &icons);
    void alwaysShowConsoleChanged();
    void waitingForInstanceChanged();
    void archPackageListDateChanged();
    void showUnknownError();
    void showNoExecutableError();
    void lastInstalledFlatpakIdChanged();
    void flatpakPhaseChanged(const QString &phase); // "downloading" | "installing"
    void systemColorsChanged();
    void lastInstalledBinaryChanged();
    void packageTypeChanged();
    void installProgressChanged();
    void showConsoleChanged();
    void showAiAuthErrorDialog(const QString &packagePath, bool isAppimage);
    void showNoAiDebWarning();
    void showNoAiRpmWarning();
    void askReloadUi();
    void localeChanged();
    void reloadQmlRequested();
    void languageChanged();
    void updatingPackageListChanged();
    void aiDescriptionUpdated();
    void aiAppDescriptionUpdated();
    void hasAiAccessChanged();
    void aiEnabledChanged();
    void openFileRequested(const QString &filePath);
    void logMessage(const QString &log);
    void requestReinstall(const QString &pkgName, const QString &location);
    void showCompleteDialog();
    void showErrorDialog();
    void switchToPage3();
    void switchToPage2();
    void switchToPage1();
    void showKillPacmanButton();
    void hideKillPacmanButton();
    void requestToken(const QString &pendingLocation);
    void executableChanged();
    void execCommandChanged();
    void iconPathChanged();
    void appNameChanged();
    void appDescriptionChanged();
    void appCategoryChanged();
    void archiveLocationChanged();
    void hasTokenChanged();
    void aiAnalyzingChanged();
    void showAppimageDialog();
    void appimageLocationChanged();
    void aiAppNameChanged();
    void aiAppDescriptionChanged();
    void aiAppCategoryChanged();
    void aiAppimageAnalyzingChanged();
    void askInstallFlatpak();
    void askReinstallFlatpak(const QString &appId);
    void aiSuggestedExecutable(const QString &execPath);
private:

    QFileSystemWatcher *m_depsWatcher { nullptr };
    bool m_installsuccess = false;
    QString m_lastProgressMsg;
    bool    m_progressLogActive { false };
    qint64  m_lastProgressEmit  { 0 };
    QString m_pendingProgressMsg;
    QTimer *m_progressFlushTimer { nullptr };
    bool m_lightMode { false };
    QStringList m_logBuffer;
    bool m_cancelledByUser { false };
    // .sh script execution
    QList<QPair<QString,QString>> m_pendingLogLines;
    QTimer *m_logThrottleTimer { nullptr };
    qint64 m_lastProgressLog { 0 };
    QStringList m_logBatch;
    QTimer *m_logFlushTimer { nullptr };
    bool        m_answerCooldown { false };   // pause after sending response
    int         m_ptyMaster  { -1 };
    int         m_ptySlave   { -1 };
    pid_t       m_shPid      { -1 };
    QSocketNotifier *m_ptyNotifier { nullptr };
    QStringList m_recentLines;          // last 20 lines
    QString     m_lineBuffer;           // current line buffer
    QTimer     *m_inputDetectTimer { nullptr };  // timer ~500ms without new output
    bool        m_waitingForShInput { false };
    int         m_shAiRequestId { 0 };
    QString m_aiModel;
    bool m_accentOnlyColors { false };
    QString m_aiProvider { "openrouter" };
    bool m_alwaysShowConsole = true;
    bool m_waitingForInstance { false };
    QString m_myLockFilePath;
    bool m_pendingFlatpakIsBundle { false };
    enum class FlatpakPhase { Idle, Downloading, Installing };
    FlatpakPhase m_flatpakPhase = FlatpakPhase::Idle;
    bool m_systemColors { false };
    QString m_lastInstalledBinary;
    QString m_installingFileName;
    QString m_packageType;
    int m_installProgress { 0 };
    bool m_showConsole { true };
    QString m_pendingAuthErrorPackage;
    bool    m_pendingAuthErrorIsAppimage { false };
    int m_locale { 0 };
    bool m_updatingPackageList { false };
    QString m_currentLanguage;
    QTranslator *m_translator { nullptr };   // required
    QString m_aiFirstAppimageDescription;
    bool m_appNameFromAI { false };
    QString m_aiFirstDescription;
    bool    m_hasAiAccess { false };
    bool    m_aiEnabled   { true };   // AI toggle state — default on
    int  m_aiRequestId { 0 };
    QString m_pendingFlatpakLocation;
    QString m_pendingFlatpakAppId;
    QString m_executable;
    QString m_execCommand;
    bool    m_execCommandCustomized { false };
    QString m_iconPath;
    QString m_appName;
    QString m_appDescription;
    QString m_appCategory     { "Utility;" };
    QString m_archiveLocation;
    bool    m_aiAnalyzing     { false };
    QNetworkAccessManager *m_networkManager;
    QString m_appimageLocation;
    QString m_aiAppName;
    QString m_aiAppDescription;
    QString m_aiAppCategory   { "Utility;" };
    bool    m_aiAppimageAnalyzing { false };
    bool m_appNameCustomized { false };
    bool m_appDescriptionFromAI    { false };
    bool m_appCategoryFromAI       { false };
    QString m_pendingDebLocation;
    QString m_pendingRpmLocation;

    QString mainWindow_clrAccentHover() { return "#bd93f9"; }

    // ── In sendShProviderRequest method — remove unnecessary parameters ──

    bool hasTray() const {
        return g_trayIcon != nullptr && g_trayIcon->isVisible();
    }

    void sendOpenRouterRaw(const QString &sys, const QString &usr,
                           std::function<void(const QByteArray&)> onRaw,
                           std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) { onError("token not found"); return; }
        QString apiKey = QString::fromUtf8(tf.readAll()).trimmed(); tf.close();

        QJsonObject body;
        body["model"] = m_aiModel.isEmpty() ? "google/gemma-4-31b-it:free" : m_aiModel;
        body["max_tokens"] = 512;
        body["temperature"] = 0.0;
        QJsonArray msgs;
        QJsonObject s; s["role"]="system"; s["content"]=sys; msgs.append(s);
        QJsonObject u; u["role"]="user";   u["content"]=usr; msgs.append(u);
        body["messages"] = msgs;

        QNetworkRequest req(QUrl("https://openrouter.ai/api/v1/chat/completions"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

        QNetworkReply *reply = m_networkManager->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [reply, onRaw, onError]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) { onError(reply->errorString()); return; }
            onRaw(reply->readAll());
        });
    }

    Q_INVOKABLE void saveConsoleFontPath(const QString &val)
    {
        QFile f(configDir() + "/console_font_path.txt");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            f.write(val.toUtf8());
            f.close();
        }
    }

    Q_INVOKABLE QString loadConsoleFontPath() const
    {
        QFile f(configDir() + "/console_font_path.txt");
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
        return QString::fromUtf8(f.readAll()).trimmed();
    }

    // ─────────────────────────────────────────
    //  Custom fonts (for console)
    // ─────────────────────────────────────────
    Q_INVOKABLE QVariantList loadCustomFonts() const
    {
        const QString fontsDirPath = configDir() + "/custom_fonts";
        QDir().mkpath(fontsDirPath);

        const QString regPath = fontsDirPath + "/registry.json";
        QJsonObject reg;
        QFile f(regPath);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QJsonParseError pe{};
            const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &pe);
            if (pe.error == QJsonParseError::NoError && doc.isObject())
                reg = doc.object();
            f.close();
        }

        QVariantList out;
        for (auto it = reg.begin(); it != reg.end(); ++it) {
            const QString fileName = it.key();
            const QString absPath  = fontsDirPath + "/" + fileName;
            if (!QFileInfo::exists(absPath))
                continue;

            QString name = it.value().toString().trimmed();
            if (name.isEmpty())
                name = QFileInfo(fileName).completeBaseName();

            QVariantMap m;
            m.insert("name", name);
            m.insert("path", absPath);
            out.push_back(m);
        }
        return out;
    }

    Q_INVOKABLE bool removeCustomFont(const QString &fontPath)
    {
        if (fontPath.trimmed().isEmpty())
            return false;

        const QString fontsDirPath = configDir() + "/custom_fonts";
        QDir().mkpath(fontsDirPath);

        const QString fileName = QFileInfo(fontPath).fileName();
        if (fileName.isEmpty())
            return false;

        // 1) remove registry entry
        const QString regPath = fontsDirPath + "/registry.json";
        QJsonObject reg;
        QFile rf(regPath);
        if (rf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QJsonParseError pe{};
            const QJsonDocument doc = QJsonDocument::fromJson(rf.readAll(), &pe);
            if (pe.error == QJsonParseError::NoError && doc.isObject())
                reg = doc.object();
            rf.close();
        }
        if (reg.contains(fileName)) {
            reg.remove(fileName);
            QFile wf(regPath);
            if (wf.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                wf.write(QJsonDocument(reg).toJson());
                wf.close();
            }
        }

        // 2) remove font file (either user provided abs path or our stored path)
        const QString storedPath = fontsDirPath + "/" + fileName;
        bool removedFile = false;
        if (QFileInfo::exists(fontPath))
            removedFile = QFile::remove(fontPath);
        if (!removedFile && QFileInfo::exists(storedPath))
            removedFile = QFile::remove(storedPath);

        return removedFile;
    }


    void saveFontRegistry(const QString &path, const QString &name)
    {
        QString regPath = configDir() + "/custom_fonts/registry.json";
        QJsonObject reg;
        QFile f(regPath);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            reg = QJsonDocument::fromJson(f.readAll()).object();
            f.close();
        }
        // Key — filename (without path) to be portable
        reg[QFileInfo(path).fileName()] = name;
        QFile fw(regPath);
        if (fw.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
            fw.write(QJsonDocument(reg).toJson());
    }

    void sendOpenAiRaw(const QString &sys, const QString &usr,
                       std::function<void(const QByteArray&)> onRaw,
                       std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/openai_token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) { onError("token not found"); return; }
        QString apiKey = QString::fromUtf8(tf.readAll()).trimmed(); tf.close();

        QJsonObject body;
        body["model"] = m_aiModel.isEmpty() ? "gpt-4o-mini" : m_aiModel;
        body["max_tokens"] = 512; body["temperature"] = 0.0;
        QJsonArray msgs;
        QJsonObject s; s["role"]="system"; s["content"]=sys; msgs.append(s);
        QJsonObject u; u["role"]="user";   u["content"]=usr; msgs.append(u);
        body["messages"] = msgs;

        QNetworkRequest req(QUrl("https://api.openai.com/v1/chat/completions"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

        QNetworkReply *reply = m_networkManager->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [reply, onRaw, onError]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) { onError(reply->errorString()); return; }
            onRaw(reply->readAll());
        });
    }

    void sendGeminiRaw(const QString &sys, const QString &usr,
                       std::function<void(const QByteArray&)> onRaw,
                       std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/gemini_token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) { onError("token not found"); return; }
        QString apiKey = QString::fromUtf8(tf.readAll()).trimmed(); tf.close();

        QString model = m_aiModel.isEmpty() ? "gemini-2.5-flash" : m_aiModel;
        QUrl url(QString("https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent?key=%2")
                     .arg(model, apiKey));

        QJsonObject userPart; userPart["text"] = sys + "\n\n" + usr;
        QJsonObject userContent; userContent["role"]="user"; userContent["parts"]=QJsonArray{userPart};
        QJsonObject genCfg; genCfg["temperature"]=0.0; genCfg["maxOutputTokens"]=512;
        QJsonObject body; body["contents"]=QJsonArray{userContent}; body["generationConfig"]=genCfg;

        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

        QNetworkReply *reply = m_networkManager->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [reply, onRaw, onError]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) { onError(reply->errorString()); return; }
            onRaw(reply->readAll());
        });
    }

    QString m_shChecklistInstruction;
    std::function<void(const QByteArray&)> m_shRawCallback;

    void startSmartArchiveExtraction(const QString &location)
    {
        QString extractedDir = QDir::homePath() + "/.cache/PackageInstaller";
        QDir(extractedDir).removeRecursively();
        if (!QDir().mkpath(extractedDir)) {
            emitLog("Error: failed to create " + extractedDir, "red");
            emit hideKillPacmanButton();
            emit showErrorDialog();
            return;
        }

        m_packageType = "extracting";
        emitLog("Extracting package...");
        emit packageTypeChanged();
        setInstallProgress(8);
        emit showKillPacmanButton();

        QProcess *proc = new QProcess(this);

        connect(proc, &QProcess::readyReadStandardOutput,
                this, [proc]() { proc->readAllStandardOutput(); });

        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc, location, extractedDir](int exitCode, QProcess::ExitStatus status) {
                    proc->deleteLater();
                    if (status != QProcess::NormalExit || exitCode != 0) {
                        emitLog("Extraction failed. Code: " + QString::number(exitCode), "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                        return;
                    }

                    emitLog("Extraction completed", greencolor());

                    // Checking .PKGINFO in the extracted folder
                    bool isArchPkg = false;
                    QDirIterator it(extractedDir,
                                    QDir::Files | QDir::Hidden | QDir::NoDotAndDotDot,
                                    QDirIterator::Subdirectories);
                    while (it.hasNext()) {
                        QString f = it.next();
                        if (QFileInfo(f).fileName() == ".PKGINFO") {
                            isArchPkg = true;
                            break;
                        }
                    }

                    if (isArchPkg) {
                        emitLog("Arch package detected");
                        QDir(extractedDir).removeRecursively();
                        m_packageType = "arch";
                        emit packageTypeChanged();
                        setInstallProgress(8);
                        installArchPkg(location);
                    } else {
                        emitLog("Generic tarboll detected");
                        m_packageType = "tarboll";
                        emit packageTypeChanged();
                        setInstallProgress(31);
                        setExecutable(""); setIconPath(""); setAppName("");
                        setAppDescription(""); setAppCategory("Utility;");
                        m_archiveLocation = location;
                        emit archiveLocationChanged();
                        emit switchToPage2();
                    }
                });

        QStringList args;
        if (location.endsWith(".zip", Qt::CaseInsensitive)) {
            proc->start("unzip", {"-o", location, "-d", extractedDir});
        } else if (location.endsWith(".tar.gz") || location.endsWith(".tgz")) {
            proc->start("tar", {"-xzf", location, "-C", extractedDir});
        } else {
            proc->start("tar", {"-xf", location, "-C", extractedDir});
        }
    }

    void sendOpenAiRequest(const QString &systemPrompt, const QString &userMsg,
                           std::function<void(const QString&, const QString&, const QString&, const QString&)> onSuccess,
                           std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/openai_token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) { onError("OpenAI token not found"); return; }
        const QString apiKey = QString::fromUtf8(tf.readAll()).trimmed(); tf.close();

        QJsonObject body;
        body["model"]       = m_aiModel.isEmpty() ? "gpt-4o-mini" : m_aiModel;
        body["max_tokens"]  = 1024;
        body["temperature"] = 0.0;
        QJsonArray msgs;
        QJsonObject sys; sys["role"] = "system"; sys["content"] = systemPrompt; msgs.append(sys);
        QJsonObject usr; usr["role"] = "user";   usr["content"] = userMsg;      msgs.append(usr);
        body["messages"] = msgs;

        QNetworkRequest req(QUrl("https://api.openai.com/v1/chat/completions"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

        QNetworkReply *reply = m_networkManager->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError]() {
            reply->deleteLater();
            int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (status == 401) { onError("OpenAI: invalid API key (401)"); if (m_aiEnabled) emit showAiCustomErrorDialog("OpenAI", "OpenAI: invalid API key (401)", 0); return; }
            if (status == 429) { onError("OpenAI: rate limit or quota exceeded (429)"); emit showAiCustomErrorDialog("OpenAI", "OpenAI: rate limit or quota exceeded (429)", 1); return; }
            if (reply->error() != QNetworkReply::NoError) {
                emit showAiCustomErrorDialog("OpenAI", reply->errorString(), 1);
                onError("OpenAI request failed: " + reply->errorString());
                return;
            }
            parseAndDeliverResult(reply->readAll(), onSuccess, onError);
        });
    }



    // REPLACE the entire sendHuggingFaceRequest with:

    void sendHuggingFaceRequest(const QString &systemPrompt, const QString &userMsg,
                                std::function<void(const QString&, const QString&, const QString&, const QString&)> onSuccess,
                                std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/huggingface_token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) { onError("Hugging Face token not found"); return; }
        const QString apiKey = QString::fromUtf8(tf.readAll()).trimmed(); tf.close();

        const QString model = m_aiModel.isEmpty() ? "meta-llama/Llama-3.2-3B-Instruct" : m_aiModel;
        QJsonObject body;
        body["model"]       = model;
        body["max_tokens"]  = 1024;
        body["temperature"] = 0.0;
        QJsonArray msgs;
        QJsonObject sys; sys["role"] = "system"; sys["content"] = systemPrompt; msgs.append(sys);
        QJsonObject usr; usr["role"] = "user";   usr["content"] = userMsg;      msgs.append(usr);
        body["messages"] = msgs;

        // ← fixed endpoint
        QNetworkRequest req(QUrl("https://api-inference.huggingface.co/v1/chat/completions"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

        QNetworkReply *reply = m_networkManager->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError]() {
            reply->deleteLater();
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QByteArray raw = reply->readAll();

            if (status == 401) {
                onError("Hugging Face: invalid token (401)");
                if (m_aiEnabled) emit showAiCustomErrorDialog("Hugging Face", "Check your API token at settings (401)", 0);
                return;
            }
            if (status == 400 || status == 403) {
                QString detail;
                QJsonDocument doc = QJsonDocument::fromJson(raw);
                if (doc.isObject()) {
                    detail = doc["error"].toString();
                    if (detail.isEmpty()) detail = doc["message"].toString();
                }
                if (detail.isEmpty()) detail = QString("HTTP %1").arg(status);
                onError("Hugging Face error: " + detail);
                if (status == 400) {
                    emit showAiCustomErrorDialog("Hugging Face", reply->errorString(), 1);
                } else {
                    emit showAiCustomErrorDialog("Hugging Face", "Check if your token has write permissions", 1);
                }
                return;
            }
            if (status == 429) {
                onError("Hugging Face: rate limit (429)");
                emit showAiCustomErrorDialog("Hugging Face", reply->errorString(), 1);
                return;
            }
            if (status == 404) {
                onError("Hugging Face: server error (404)");
                emit showAiCustomErrorDialog("Hugging Face", "Server replied with status code 404", 1);
                return;
            }
            if (reply->error() != QNetworkReply::NoError) {
                onError("Hugging Face request failed: " + reply->errorString());
                emit showAiCustomErrorDialog("Hugging Face", reply->errorString(), 1);
                return;
            }
            parseAndDeliverResult(raw, onSuccess, onError);
        });
    }

    void doStartDebConversion(const QString &location)
    {
        setInstallProgress(8);
        DebExctractionCompleted();
        emitLog("Trying to convert debian package to arch format");
        emit showKillPacmanButton();

        QString dirdebtapoutput = QString::fromUtf8(getenv("HOME")) + "/.cache/debtapoutput";
        QDir outDir(dirdebtapoutput);
        if (outDir.exists()) outDir.removeRecursively();
        QDir().mkpath(dirdebtapoutput);

        QString debtapPath = "/opt/packageinstaller/scripts/debtap";
        emitLog("debtap binary: " + debtapPath);
        emitLog("output dir:    " + dirdebtapoutput);

        if (!QFileInfo::exists(debtapPath)) {
            emitLog("ERROR: debtap not found at " + debtapPath, "red");
            emit hideKillPacmanButton();
            emit showErrorDialog();
            return;
        }

        QProcess *proc = new QProcess(this);
        connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc]() {
            QString out = stripAnsi(QString::fromUtf8(proc->readAllStandardOutput()).trimmed());
            if (!out.isEmpty()) emitLog(out);
        });
        connect(proc, &QProcess::readyReadStandardError, this, [this, proc]() {
            QString err = stripAnsi(QString::fromUtf8(proc->readAllStandardError()).trimmed());
            if (!err.isEmpty()) emitLog(err, greycolor());
        });
        connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError err) {
            Q_UNUSED(proc)
            QString r;
            switch (err) {
            case QProcess::FailedToStart: r = "FailedToStart — binary missing or not executable?"; break;
            case QProcess::Crashed:       r = "Crashed";      break;
            case QProcess::Timedout:      r = "Timedout";     break;
            default:                      r = "UnknownError"; break;
            }
            emitLog("debtap error: " + r, "red");
            emit hideKillPacmanButton();
            emit showErrorDialog();
        });
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, dirdebtapoutput, proc](int exitCode, QProcess::ExitStatus status) {
                    proc->deleteLater();

                    // Exit code 3 = AI auth error, package still created
                    if (exitCode == 3) {
                        emitLog("AI auth error — invalid token. Package may have untranslated dependencies.", orange());
                        QDir dir(dirdebtapoutput);
                        QStringList files = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);
                        if (!files.isEmpty()) {
                            m_pendingAuthErrorPackage = dir.absoluteFilePath(files.first());
                            m_pendingAuthErrorIsAppimage = false;
                            emit hideKillPacmanButton();
                            emit showAiAuthErrorDialog(m_pendingAuthErrorPackage, false);
                        } else {
                            emit hideKillPacmanButton();
                            emit showErrorDialog();
                        }
                        return;
                    }

                    if (status == QProcess::NormalExit && exitCode == 0) {
                        emitLog("Conversion completed successfully", greencolor());
                        QDir dir(dirdebtapoutput);
                        QStringList files = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);
                        if (files.isEmpty()) {
                            emitLog("No output file found after conversion", "red");
                            emit hideKillPacmanButton();
                            emit showErrorDialog();
                            return;
                        } else {
                            setInstallProgress(77);
                            installArchPkg(dir.absoluteFilePath(files.first()));
                        }
                    } else {
                        emitLog("Conversion failed with exit code " + QString::number(exitCode), "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                    }
                });

        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        if (!m_hasAiAccess) {
            env.insert("SKIP_AI", "1");
        } else {
            env.insert("AI_PROVIDER", m_aiProvider);
            env.insert("AI_MODEL", m_aiModel);
            if (m_aiProvider == "gemini")
                env.insert("AI_TOKEN", loadGeminiToken());
            else if (m_aiProvider == "openai")
                env.insert("AI_TOKEN", loadOpenAiToken());
            else if (m_aiProvider == "huggingface")
                env.insert("AI_TOKEN", loadHuggingFaceToken());
            else if (m_aiProvider == "mistral")
                env.insert("AI_TOKEN", loadMistralToken());
            else
                env.insert("AI_TOKEN", loadToken()); // openrouter
        }
        env.insert("SHOW_DEPS_WINDOW", loadDependenciesSwitch() ? "1" : "0");
        {
            QString lockNum = "0";
            if (!m_myLockFilePath.isEmpty()) {
                QRegularExpression reLock("lock(\\d+)$");
                QRegularExpressionMatch lm = reLock.match(m_myLockFilePath);
                if (lm.hasMatch()) lockNum = lm.captured(1);
            }
            env.insert("INSTALLER_LOCK_NUMBER", lockNum);
        }
        proc->setProcessEnvironment(env);
        proc->start("/bin/bash", {debtapPath, "-Q", "-o", dirdebtapoutput, location});
    }

    void DebExctractionCompleted() {
        QFileSystemWatcher *watcher = new QFileSystemWatcher(this);
        watcher->addPath(QDir::homePath() + "/.cache");
        QString extractdone = QDir::homePath() + "/.cache/extract_done";

        connect(watcher, &QFileSystemWatcher::directoryChanged, this,
                [this, watcher, extractdone](const QString &) {
                    if (QFile::exists(extractdone)) {
                        setInstallProgress(31);
                        DebConversionCompleted();
                        QFile::remove(extractdone);
                        watcher->deleteLater(); // remove watcher after it triggers
                    }
                });
    }



    void DebConversionCompleted() {
        QFileSystemWatcher *watcher = new QFileSystemWatcher(this);
        watcher->addPath(QDir::homePath() + "/.cache");
        QString convertdone = QDir::homePath() + "/.cache/convert_done";

        connect(watcher, &QFileSystemWatcher::directoryChanged, this,
                [this, watcher, convertdone](const QString &) {
                    if (QFile::exists(convertdone)) {
                        setInstallProgress(54);
                        QFile::remove(convertdone);
                        watcher->deleteLater();
                    }
                });
    }

    void doStartRpmConversion(const QString &location)
    {
        setInstallProgress(8);
        DebExctractionCompleted();
        emitLog("Trying to convert RPM package to Arch format");

        QString dirOutput = QString::fromUtf8(getenv("HOME")) + "/.cache/rpmtapoutput";
        QDir outDir(dirOutput);
        if (outDir.exists()) outDir.removeRecursively();
        QDir().mkpath(dirOutput);

        QString rpmtapPath = "/opt/packageinstaller/scripts/rpmtap";
        emitLog("rpmtap binary: " + rpmtapPath);
        emitLog("output dir:    " + dirOutput);

        if (!QFileInfo::exists(rpmtapPath)) {
            emitLog("ERROR: rpmtap not found at " + rpmtapPath, "red");
            emit hideKillPacmanButton();
            emit showErrorDialog();
            return;
        }

        QProcess *proc = new QProcess(this);
        connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc]() {
            QString out = stripAnsi(QString::fromUtf8(proc->readAllStandardOutput()).trimmed());
            if (!out.isEmpty()) emitLog(out);
        });
        connect(proc, &QProcess::readyReadStandardError, this, [this, proc]() {
            QString err = stripAnsi(QString::fromUtf8(proc->readAllStandardError()).trimmed());
            if (!err.isEmpty()) emitLog(err, greycolor());
        });
        connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError err) {
            Q_UNUSED(proc)
            QString r;
            switch (err) {
            case QProcess::FailedToStart: r = "FailedToStart — binary missing or not executable?"; break;
            case QProcess::Crashed:       r = "Crashed";      break;
            case QProcess::Timedout:      r = "Timedout";     break;
            default:                      r = "UnknownError"; break;
            }
            emitLog("rpmtap error: " + r, "red");
            emit hideKillPacmanButton();
            emit showErrorDialog();
        });
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, dirOutput, proc](int exitCode, QProcess::ExitStatus status) {
                    proc->deleteLater();

                    if (exitCode == 3) {
                        emitLog("AI auth error — invalid token. Package may have untranslated dependencies.", orange());
                        QDir dir(dirOutput);
                        QStringList files = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);
                        if (!files.isEmpty()) {
                            m_pendingAuthErrorPackage = dir.absoluteFilePath(files.first());
                            m_pendingAuthErrorIsAppimage = false;
                            emit hideKillPacmanButton();
                            emit showAiAuthErrorDialog(m_pendingAuthErrorPackage, false);
                        } else {
                            emit hideKillPacmanButton();
                            emit showErrorDialog();
                        }
                        return;
                    }

                    if (status == QProcess::NormalExit && exitCode == 0) {
                        emitLog("RPM conversion completed successfully", greencolor());
                        setInstallProgress(77);
                        QDir dir(dirOutput);
                        QStringList files = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);
                        if (files.isEmpty()) {
                            emitLog("No output file found after RPM conversion", "red");
                            emit hideKillPacmanButton();
                            emit showErrorDialog();
                            return;
                        }
                        installArchPkg(dir.absoluteFilePath(files.first()));
                    } else {
                        emitLog("RPM conversion failed with exit code " + QString::number(exitCode), "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                    }
                });

        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        if (!m_hasAiAccess) {
            env.insert("SKIP_AI", "1");
        } else {
            env.insert("AI_PROVIDER", m_aiProvider);
            env.insert("AI_MODEL", m_aiModel);
            if (m_aiProvider == "gemini")
                env.insert("AI_TOKEN", loadGeminiToken());
            else if (m_aiProvider == "openai")
                env.insert("AI_TOKEN", loadOpenAiToken());
            else if (m_aiProvider == "huggingface")
                env.insert("AI_TOKEN", loadHuggingFaceToken());
            else if (m_aiProvider == "mistral")
                env.insert("AI_TOKEN", loadMistralToken());
            else
                env.insert("AI_TOKEN", loadToken());
        }
        env.insert("SHOW_DEPS_WINDOW", loadDependenciesSwitch() ? "1" : "0"); // ← add
        {
            QString lockNum = "0";
            if (!m_myLockFilePath.isEmpty()) {
                QRegularExpression reLock("lock(\\d+)$");
                QRegularExpressionMatch lm = reLock.match(m_myLockFilePath);
                if (lm.hasMatch()) lockNum = lm.captured(1);
            }
            env.insert("INSTALLER_LOCK_NUMBER", lockNum);
        }
        proc->setProcessEnvironment(env);
        proc->start("/bin/bash", {rpmtapPath, "-Q", "-o", dirOutput, location});
    }

    void extractAndShowDebDeps(const QString &location)
    {
        QProcess proc;
        proc.start("dpkg-deb", {"-f", location, "Depends"});
        proc.waitForFinished(5000);
        QString deps = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (!deps.isEmpty()) {
            emitLog("Dependencies to install manually:", orange());
            for (const QString &dep : deps.split(',')) {
                emitLog("  pacman -S " + dep.trimmed().split(' ').first(), orange());
            }
        }
    }

    void extractAndShowRpmDeps(const QString &location)
    {
        QProcess proc;
        proc.start("rpm", {"-qp", "--requires", location});
        proc.waitForFinished(5000);
        QString deps = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (!deps.isEmpty()) {
            emitLog("Dependencies to install manually:", orange());
            for (const QString &dep : deps.split('\n')) {
                QString d = dep.trimmed().split(' ').first();
                if (!d.isEmpty() && !d.startsWith("/") && !d.startsWith("rpmlib"))
                    emitLog("  pacman -S " + d, orange());
            }
        }
    }

    void setExecCommandRaw(const QString &val, bool customized = false) {
        if (m_execCommand == val && m_execCommandCustomized == customized) return;
        m_execCommand = val;
        m_execCommandCustomized = customized;
        emit execCommandChanged();
    }

    void buildDefaultExecCommand() {
        QString pkgNameLower = m_appName.toLower().replace(" ", "-");

        QString execName = QFileInfo(m_executable).fileName();
        // if (execName.endsWith(".sh"))
        //     execName = execName.left(execName.length() - 3);

        // Get the relative path from rootDir
        std::string extractedDir = getExtractedDir().toStdString();
        std::string rootDir = normalizeExtractedDir(extractedDir);
        QString qRootDir = QString::fromStdString(rootDir);

        QString execRelPath = m_executable;
        if (execRelPath.startsWith(qRootDir))
            execRelPath = execRelPath.mid(qRootDir.length());
        if (execRelPath.startsWith("/"))
            execRelPath = execRelPath.mid(1);

        setExecCommandRaw("/usr/lib/" + (pkgNameLower.isEmpty() ? "app" : pkgNameLower)
                              + "/" + (execRelPath.isEmpty() ? execName : execRelPath) + " %u", false);
    }

    void setAppDescriptionFromAI(const QString &val) {
        if (m_appDescription == val) return;
        m_appDescription = val;
        m_appDescriptionFromAI = true;
        if (m_aiFirstDescription.isEmpty())
            m_aiFirstDescription = val;
        emit appDescriptionChanged();
        emit aiDescriptionUpdated();
    }

    void setAppCategoryFromAI(const QString &val) {
        if (m_appCategory == val) return;
        m_appCategory = val;
        m_appCategoryFromAI = true;
        emit appCategoryChanged();
    }

    static QString stripAnsi(const QString &text)
    {
        QString result = text;
        static const QRegularExpression ansiEscape(
            R"(\x1B(?:[@-Z\\-_]|\[[0-9;]*[ -/]*[@-~]|\([A-Z]))");
        result.remove(ansiEscape);
        return result;
    }



    static QString helperPath()
    {
        return QCoreApplication::applicationDirPath() + "/packageinstaller-helper";
    }

    void sendAiRequest(const QString &context,
                       std::function<void(const QString&, const QString&, const QString&, const QString&)> onSuccess,
                       std::function<void(const QString&)> onError)
    {
        static const QString CATEGORIES_GUIDE = R"(
MAIN CATEGORIES — choose exactly one:
  AudioVideo   Multimedia players, editors, recorders (audio + video)
  Audio        Audio-only: music players, audio editors, mixers
  Video        Video-only: players, editors, converters
  Development  IDEs, debuggers, compilers, VCS clients, code editors
  Education    Educational software, learning tools, flashcards, dictionaries
  Game         Any kind of game
  Graphics     Image editors/viewers, 3D tools, CAD, photo managers, screen capture
  Network      Web browsers, email, chat, VPN, download managers, FTP clients
  Office       Word processors, spreadsheets, presentations, PDF tools, calendars
  Science      Scientific/math tools, astronomy, chemistry, physics simulators
  Settings     System/desktop settings panels and configuration tools
  System       File managers, terminals, system monitors, disk tools, package managers
  Utility      Calculators, text editors, launchers, clipboard tools, misc

OUTPUT FORMAT: "PrimaryCategory;OptionalExtra;"
Examples: "Network;WebBrowser;"  "Game;Strategy;"  "Development;TextEditor;"  "Utility;"
)";

        const QString systemPrompt =
            "You are a Linux application metadata expert.\n"
            "Given information about an application, return ONLY a JSON object with:\n"
            "  \"name\"        - Clean display name (Title Case, no version numbers)\n"
            "  \"description\" - One sentence, max 100 chars, start with a verb\n"
            "  \"category\"    - freedesktop.org Categories string\n"
            "  \"executable\"  - Filename (not path) of the best executable to launch the app.\n"
            "                   Choose from the 'Available executables' list. Pick the main app binary,\n"
            "                   not updaters, helpers, or crash reporters.\n"
            "                   If only one executable exists or you are unsure, leave empty string.\n\n"
            + CATEGORIES_GUIDE +
            "\n\nRULES:\n"
            "- Return ONLY valid JSON, no markdown fences, no explanation\n"
            "- name: proper display name (e.g. \"Firefox\", \"VS Code\", \"GIMP\")\n"
            "- description: concise and informative\n"
            "- category: exact names from the list, semicolon-separated, ending with ;\n"
            "- If unsure about category, use \"Utility;\"\n\n"
            "Example: {\"name\":\"Firefox\",\"description\":\"Fast and private open-source web browser\","
            "\"category\":\"Network;WebBrowser;\"}";

        const QString userMsg =
            "Analyze this Linux application and return its metadata as JSON:\n\n" + context;

        if      (m_aiProvider == "gemini")      sendGeminiRequest(systemPrompt, userMsg, onSuccess, onError);
        else if (m_aiProvider == "openai")      sendOpenAiRequest(systemPrompt, userMsg, onSuccess, onError);
        else if (m_aiProvider == "huggingface") sendHuggingFaceRequest(systemPrompt, userMsg, onSuccess, onError);
        else if (m_aiProvider == "mistral")     sendMistralRequest(systemPrompt, userMsg, onSuccess, onError);
        else                                    sendOpenRouterRequest(systemPrompt, userMsg, onSuccess, onError);
    }

    // ── OpenRouter (existing logic, just moved to a separate method) ──────────
    void sendOpenRouterRequest(const QString &systemPrompt,
                               const QString &userMsg,
                               std::function<void(const QString&, const QString&, const QString&, const QString&)> onSuccess,
                               std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            onError("AI token not found");
            return;
        }
        const QString apiKey = QString::fromUtf8(tf.readAll()).trimmed();
        tf.close();

        QJsonObject body;
        body["model"] = m_aiModel.isEmpty() ? "google/gemma-4-31b-it:free" : m_aiModel;
        body["max_tokens"]  = 1024;
        body["temperature"] = 0.0;

        QJsonArray msgs;
        QJsonObject sys; sys["role"] = "system"; sys["content"] = systemPrompt; msgs.append(sys);
        QJsonObject usr; usr["role"] = "user";   usr["content"] = userMsg;      msgs.append(usr);
        body["messages"] = msgs;

        QNetworkRequest req(QUrl("https://openrouter.ai/api/v1/chat/completions"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setRawHeader("HTTP-Referer",  "https://github.com/PackageInstaller");
        req.setRawHeader("X-Title",       "PackageInstaller");

        QNetworkReply *reply = m_networkManager->post(
            req, QJsonDocument(body).toJson(QJsonDocument::Compact));

        connect(reply, &QNetworkReply::finished, this,
                [this, reply, onSuccess, onError]() mutable {
                    reply->deleteLater();

                    int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                    if (httpStatus == 402) {
                        onError("AI request failed: payment required (402)");
                        emit showAiCustomErrorDialog("OpenRouter", "Payment required (402)", 1);
                        return;
                    }
                    if (reply->error() != QNetworkReply::NoError) {
                        onError("AI analysis failed: " + reply->errorString());
                        if (m_aiEnabled) emit showAiCustomErrorDialog("OpenRouter", reply->errorString(), 1);
                        return;
                    }

                    parseAndDeliverResult(reply->readAll(), onSuccess, onError);
                });
    }

    // ── Gemini API ────────────────────────────────────────────────────────────
    void sendGeminiRequest(const QString &systemPrompt,
                           const QString &userMsg,
                           std::function<void(const QString&, const QString&, const QString&, const QString&)> onSuccess,
                           std::function<void(const QString&)> onError)
    {
        QFile tf(configDir() + "/gemini_token.txt");
        if (!tf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            onError("Gemini token not found");
            return;
        }
        const QString apiKey = QString::fromUtf8(tf.readAll()).trimmed();
        tf.close();

        // Gemini 2.0 Flash — free and fast
        const QString model = m_aiModel.isEmpty() ? "gemini-2.5-flash" : m_aiModel;
        QUrl url(QString("https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent?key=%2")
                     .arg(model, apiKey));

        // Gemini uses a different format: system instruction + user content
        QJsonObject systemInstruction;
        QJsonObject sysPart;
        sysPart["text"] = systemPrompt;
        systemInstruction["parts"] = QJsonArray{ sysPart };

        // Gemini — combine system prompt and user message into one content
        QJsonObject userPart;
        userPart["text"] = systemPrompt + "\n\n" + userMsg;
        QJsonObject userContent;
        userContent["role"]  = "user";
        userContent["parts"] = QJsonArray{ userPart };

        QJsonObject generationConfig;
        generationConfig["temperature"]     = 0.0;
        generationConfig["maxOutputTokens"] = 1024;

        QJsonObject body;
        body["contents"]         = QJsonArray{ userContent };
        body["generationConfig"] = generationConfig;

        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

        QNetworkReply *reply = m_networkManager->post(
            req, QJsonDocument(body).toJson(QJsonDocument::Compact));

        connect(reply, &QNetworkReply::finished, this,
                [this, reply, onSuccess, onError]() mutable {
                    reply->deleteLater();

                    int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

                    if (reply->error() != QNetworkReply::NoError) {
                        // 400 = invalid key or request, 403 = access denied
                        if (httpStatus == 400 || httpStatus == 403) {
                            onError(QString("Gemini API error %1: check your API key").arg(httpStatus));
                            if (httpStatus == 400)
                                emit showAiCustomErrorDialog("Gemini", "Check your API key at settings (400)", 0);
                            else
                                emit showAiCustomErrorDialog("Gemini", "Acess denied (403)", 1);
                            return;
                        }
                        if (httpStatus == 429) {
                            onError("Gemini rate limit reached (429)");
                            emit showAiCustomErrorDialog("Gemini", reply->errorString(), 1);
                            return;
                        }
                        onError("Gemini request failed: " + reply->errorString());
                        emit showAiCustomErrorDialog("Gemini", reply->errorString(), 1);
                        return;
                    }

                    QByteArray raw = reply->readAll();
                    // emitLog("Gemini raw response: " + QString::fromUtf8(raw.left(500)), greycolor()); // ← add
                    QJsonParseError pe;
                    QJsonDocument doc = QJsonDocument::fromJson(raw, &pe);
                    if (pe.error != QJsonParseError::NoError) {
                        onError("Gemini response parse error: " + pe.errorString());
                        if (m_aiEnabled) emit showAiCustomErrorDialog("Gemini", "Gemini did not return a valid JSON", 2);
                        return;
                    }

                    // Gemini format: candidates[0].content.parts[0].text
                    QString content = doc["candidates"][0]["content"]["parts"][0]["text"]
                                          .toString().trimmed();

                    if (content.isEmpty()) {
                        // Checking for blocking via safety filters
                        QString finishReason = doc["candidates"][0]["finishReason"].toString();
                        if (finishReason == "SAFETY") {
                            onError("Gemini blocked response due to safety filters");
                            return;
                        }
                        onError("Gemini returned empty response");
                        if (m_aiEnabled) emit showAiCustomErrorDialog("Gemini", "Gemini returned an empty responce", 2);
                        return;
                    }

                    // Aggressive cleaning from markdown and extra text
                    content.remove(QRegularExpression("^[\\s\\S]*?(?=\\{)"));  // everything before the first {
                    content.remove(QRegularExpression("\\}[\\s\\S]*$"));        // everything after the last }
                    // restore the closing bracket that might have been removed
                    if (!content.endsWith("}")) content += "}";
                    content = content.trimmed();



                    parseAndDeliverResult(content.toUtf8(), onSuccess, onError);
                });
    }

    // ── Shared JSON response parsing ──────────────────────────────────────
    void parseAndDeliverResult(const QByteArray &raw,
                               std::function<void(const QString&, const QString&, const QString&, const QString&)> onSuccess,
                               std::function<void(const QString&)> onError)
    {
        QJsonParseError pe;

        // For OpenRouter — extract content from choices[0]
        QJsonDocument doc = QJsonDocument::fromJson(raw, &pe);
        QByteArray contentBytes = raw;

        if (pe.error == QJsonParseError::NoError && doc.isObject()) {
            QJsonObject obj = doc.object();

            // OpenRouter / OpenAI-compatible format
            if (obj.contains("choices")) {
                QString content = obj["choices"][0]["message"]["content"].toString().trimmed();
                if (content.isEmpty()) {
                    if (m_aiEnabled) showAiCustomErrorDialog("OpenRouter", "AI returned an empty response", 2);
                    onError("AI returned empty response");
                    return;
                }
                // Checking for API error object
                if (obj.contains("error")) {
                    QString apiErr = obj["error"].toObject()["message"].toString();
                    if (apiErr.isEmpty()) apiErr = "Unknown API error";
                    onError("AI API error: " + apiErr);
                    if (m_aiEnabled)
                        emit showAiCustomErrorDialog("OpenRouter", "AI API error: " + apiErr, 1);
                    return;
                }
                content.remove(QRegularExpression("^```[a-z]*\\n?"));
                content.remove(QRegularExpression("\\n?```$"));
                contentBytes = content.trimmed().toUtf8();
            }
            // Gemini — text already extracted earlier, raw is already clean JSON
        }

        QJsonDocument rd = QJsonDocument::fromJson(contentBytes, &pe);
        if (pe.error != QJsonParseError::NoError || !rd.isObject()) {
            onError("AI returned invalid JSON — skipping");
            if (m_aiEnabled) emit showAiCustomErrorDialog("OpenRouter", "AI returned invalid data", 2);
            return;
        }

        QJsonObject result = rd.object();
        onSuccess(result["name"].toString().trimmed(),
                  result["description"].toString().trimmed(),
                  result["category"].toString().trimmed(),
                  result["executable"].toString().trimmed());
    }

    void installArchPkg(const QString &location)
    {
        if (m_packageType == "tarboll") {
            setInstallProgress(77);
        } else if (m_packageType == "dir") {
            setInstallProgress(77);
        }
        QProcess checkPkg;
        checkPkg.start("pacman", {"-Qp", location});
        checkPkg.waitForFinished();
        QString newPkgName = QString::fromUtf8(checkPkg.readAllStandardOutput())
                                 .split(" ").first().trimmed();

        if (newPkgName.isEmpty()) {
            emitLog("Could not determine package name", "red");
            emit showErrorDialog();
            return;
        }

        QProcess checkExact;
        checkExact.start("/bin/sh", {"-c",
                                     "pacman -Qq | grep -x \"" + newPkgName + "\""});
        checkExact.waitForFinished();
        if (checkExact.exitCode() == 0) {
            emit requestReinstall(newPkgName, location);
            return;
        }

        QProcess listAll;
        listAll.start("pacman", {"-Qq"});
        listAll.waitForFinished(5000);
        QString allPkgs = QString::fromUtf8(listAll.readAllStandardOutput());

        QString conflicting;
        for (const QString &line : allPkgs.split('\n', Qt::SkipEmptyParts)) {
            QString pkg = line.trimmed();
            if (pkg != newPkgName && pkg.startsWith(newPkgName)) {
                conflicting = pkg;
                break;
            }
        }

        if (!conflicting.isEmpty()) {
            emitLog("Found conflicting package: " + conflicting + " (will replace with " + newPkgName + ")", orange());
            emit requestReinstall(conflicting, location);
            return;
        }

        auto findOwner = [&](const QString &path) -> QString {
            QProcess p;
            p.start("pacman", {"-Qqo", path});
            p.waitForFinished(3000);
            if (p.exitCode() != 0) return QString();
            return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
        };

        QStringList conflictingPkgs;
        for (const QString &checkPath : {"/usr/bin/" + newPkgName, "/usr/lib/" + newPkgName}) {
            QString owner = findOwner(checkPath);
            if (!owner.isEmpty() && owner != newPkgName && !conflictingPkgs.contains(owner))
                conflictingPkgs << owner;
        }

        if (!conflictingPkgs.isEmpty()) {
            emitLog("Found conflicting package(s): " + conflictingPkgs.join(", "), orange());
            emit requestReinstall(conflictingPkgs.first(), location);
        } else {
            runHelperAsync("install-pkg", {location});
        }
    }

    void removePackagesAndInstall(const QStringList &pkgsToRemove, const QString &locationToInstall)
    {
        if (pkgsToRemove.isEmpty()) {
            runHelperAsync("install-pkg", {locationToInstall});
            return;
        }

        QString pkgName = pkgsToRemove.first();
        QStringList remaining = pkgsToRemove.mid(1);

        QProcess *removeProc = new QProcess(this);
        connect(removeProc, &QProcess::readyReadStandardOutput, this, [this, removeProc]() {
            QString out = stripAnsi(QString::fromUtf8(removeProc->readAllStandardOutput()).trimmed());
            if (!out.isEmpty()) emitLog(out);
        });
        connect(removeProc, &QProcess::readyReadStandardError, this, [this, removeProc]() {
            QString err = stripAnsi(QString::fromUtf8(removeProc->readAllStandardError()).trimmed());
            if (!err.isEmpty()) emitLog(err, greycolor());
        });
        connect(removeProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, removeProc, remaining, locationToInstall, pkgName]
                (int exitCode, QProcess::ExitStatus status) {
                    removeProc->deleteLater();
                    if (status != QProcess::NormalExit || exitCode != 0) {
                        emitLog("Warning: could not remove " + pkgName + ", continuing anyway", orange());
                    } else {
                        emitLog("Removed conflicting package: " + pkgName, greencolor());
                    }
                    removePackagesAndInstall(remaining, locationToInstall);
                });

        removeProc->start("pkexec", {helperPath(), "remove-pkg", pkgName});
    }

    void startRpmConversion(const QString &location)
    {
        emitLog("RPM package detected");

        if (!m_hasAiAccess) {
            if (loadRpmNoAiWarningDisabled()) {
                doStartRpmConversion(location);
                return;
            }
            m_pendingRpmLocation = location;
            emit showNoAiRpmWarning();
            return;
        }

        doStartRpmConversion(location);
    }

    void startDebConversion(const QString &location)
    {
        emitLog("Debian package detected");

        if (!m_hasAiAccess) {
            if (loadDebNoAiWarningDisabled()) {
                doStartDebConversion(location);
                return;
            }
            m_pendingDebLocation = location;
            emit showNoAiDebWarning();
            return;
        }

        doStartDebConversion(location);
    }

    void runHelperAsync(const QString &command, const QStringList &args)
    {
        QStringList fullArgs;
        fullArgs << helperPath() << command << args;

        QProcess *process = new QProcess(this);

        connect(process, &QProcess::readyReadStandardOutput, this, [this, process, command]() {
            QString raw = stripAnsi(QString::fromUtf8(process->readAllStandardOutput()));
            if (raw.isEmpty()) return;

            for (const QString &line : raw.split('\n', Qt::SkipEmptyParts)) {
                QString trimmed = line.trimmed();
                if (trimmed.isEmpty()) continue;


                if ((command == "install-flatpak" || command == "install-flatpak-bundle") && trimmed.startsWith("[installing]"))
                {
                    if (m_flatpakPhase == FlatpakPhase::Installing) continue;

                    if (!m_lastProgressMsg.isEmpty()) {
                        static QRegularExpression reFinal(R"([\d.]+(\s*/\s*([\d.]+)\s*MB\s*)\(\d+%\))");
                        QRegularExpressionMatch match = reFinal.match(m_lastProgressMsg);

                        if (match.hasMatch()) {
                            QString totalMb = match.captured(2);
                            m_lastProgressMsg.replace(reFinal, QString("%1%2(100%)").arg(totalMb).arg(match.captured(1)));
                            emitProgressLog(m_lastProgressMsg, false);
                            m_lastProgressMsg.clear();
                        }
                    }

                    emit flatpakPhaseChanged("installing");
                    setInstallProgress(54);
                    emitLog("Installing package...");
                    m_flatpakPhase = FlatpakPhase::Installing;
                    continue;
                }
                // Flatpak progress
                if ((command == "install-flatpak" || command == "install-flatpak-bundle")
                    && trimmed.startsWith("[progress] "))
                {
                    if (m_flatpakPhase == FlatpakPhase::Installing) continue;

                    static QRegularExpression re(
                        R"(\[progress\]\s+([\d.]+)\s*/\s*([\d.]+)\s*MB\s*\((\d+)%\)\s*\[(\d+)/(\d+)\])");
                    QRegularExpressionMatch m = re.match(trimmed);
                    if (m.hasMatch()) {
                        double dl    = m.captured(1).toDouble();
                        double total = m.captured(2).toDouble();
                        int    pct   = m.captured(3).toInt();
                        int    opIdx = m.captured(4).toInt();
                        int    opTot = m.captured(5).toInt();

                        if (m_flatpakPhase == FlatpakPhase::Idle) {
                            m_flatpakPhase = FlatpakPhase::Downloading;
                            emit flatpakPhaseChanged("downloading");
                            setInstallProgress(8);
                        }

                        int mappedPct = 8 + (pct * (54 - 8)) / 100;
                        setInstallProgress(mappedPct);

                        QString msg = QString("Downloading (%1/%2): %3 / %4 MB (%5%)")
                                          .arg(opIdx).arg(opTot)
                                          .arg(dl, 0, 'f', 1)
                                          .arg(total, 0, 'f', 1)
                                          .arg(pct);

                        m_lastProgressMsg = msg;

                        emitProgressLog(msg, true);
                    }
                    continue;
                }

                m_progressLogActive = false;
                emitLog(trimmed);
            }
        });

        connect(process, &QProcess::readyReadStandardError, this, [this, process]() {
            QString err = stripAnsi(QString::fromUtf8(process->readAllStandardError()).trimmed());
            if (!err.isEmpty()) emitLog(err, "red");
        });

        connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, command, process, args](int exitCode, QProcess::ExitStatus status) {
                    process->deleteLater();
                    m_flatpakPhase = FlatpakPhase::Idle;
                    m_progressLogActive = false;

                    if (status == QProcess::NormalExit && exitCode == 0) {
                        setInstallProgress(100);
                        rmAlltempfiles();

                        if (command == "install-flatpak" || command == "install-flatpak-bundle") {
                            if (m_pendingFlatpakAppId.isEmpty()) {
                                QProcess q;
                                q.start("sh", {"-c",
                                               "flatpak list --app --columns=application | sort | tail -1"});
                                q.waitForFinished(3000);
                                QString detected = QString::fromUtf8(q.readAllStandardOutput()).trimmed();
                                if (!detected.isEmpty())
                                    m_pendingFlatpakAppId = detected;
                            }
                            if (!m_pendingFlatpakAppId.isEmpty()) {
                                m_lastInstalledFlatpakId = m_pendingFlatpakAppId;
                                emit lastInstalledFlatpakIdChanged();
                            }
                            m_lastInstalledBinary = "__flatpak__:" + m_pendingFlatpakAppId;
                            emit lastInstalledBinaryChanged();

                        } else if (!args.isEmpty()) {
                            QProcess pkgq;
                            pkgq.start("pacman", {"-Qp", args.first()});
                            pkgq.waitForFinished(3000);
                            QString pkgName = QString::fromUtf8(pkgq.readAllStandardOutput())
                                                  .split(" ").first().trimmed();
                            if (!pkgName.isEmpty()) {
                                m_lastInstalledBinary = "/usr/bin/" + pkgName;
                                emit lastInstalledBinaryChanged();
                            }
                        }

                        emitLog("Application installed successfully", greencolor());
                        emit requestLogReplacement("Downloading", "done");
                        m_installsuccess = true;
                        emit hideKillPacmanButton();
                        emit showCompleteDialog();

                    } else {
                        if (command == "install-flatpak-bundle" || command == "install-flatpak") {
                            QProcess checkInstalled;
                            checkInstalled.start("flatpak", {"list", "--app", "--columns=application"});
                            checkInstalled.waitForFinished(5000);
                            QString installedList = QString::fromUtf8(checkInstalled.readAllStandardOutput());

                            if (!m_pendingFlatpakAppId.isEmpty()) {
                                for (const QString &line : installedList.split('\n')) {
                                    if (line.trimmed() == m_pendingFlatpakAppId) {
                                        emitLog("Package already installed, asking for reinstall...", orange());
                                        m_pendingFlatpakLocation = args.isEmpty() ? "" : args.first();
                                        m_pendingFlatpakIsBundle = (command == "install-flatpak-bundle");
                                        emit askReinstallFlatpak(m_pendingFlatpakAppId);
                                        return;
                                    }
                                }
                            } else if (command == "install-flatpak-bundle") {
                                QString bundlePath = args.isEmpty() ? "" : args.first();
                                QString detectedId;

                                QProcess q1;
                                q1.start("sh", {"-c",
                                                QString("ostree refs --repo '%1' 2>/dev/null | grep '^app/' | head -1 | cut -d/ -f2")
                                                    .arg(bundlePath)});
                                q1.waitForFinished(5000);
                                detectedId = QString::fromUtf8(q1.readAllStandardOutput()).trimmed();

                                if (detectedId.isEmpty()) {
                                    QProcess q2;
                                    q2.start("sh", {"-c",
                                                    QString("flatpak bundle-info '%1' 2>/dev/null | grep '^Ref:' | sed 's|.*app/||;s|/.*||'")
                                                        .arg(bundlePath)});
                                    q2.waitForFinished(5000);
                                    detectedId = QString::fromUtf8(q2.readAllStandardOutput()).trimmed();
                                }

                                if (!detectedId.isEmpty()) {
                                    for (const QString &line : installedList.split('\n')) {
                                        if (line.trimmed() == detectedId) {
                                            emitLog("Package already installed (" + detectedId + "), asking for reinstall...", orange());
                                            m_pendingFlatpakAppId = detectedId;
                                            m_pendingFlatpakLocation = bundlePath;
                                            m_pendingFlatpakIsBundle = true;
                                            emit askReinstallFlatpak(detectedId);
                                            return;
                                        }
                                    }
                                } else {
                                    QString baseName = QFileInfo(bundlePath).baseName().toLower();
                                    for (const QString &line : installedList.split('\n')) {
                                        QString appId = line.trimmed();
                                        if (appId.isEmpty()) continue;
                                        QString shortName = appId.split('.').last().toLower();
                                        if (!shortName.isEmpty() && baseName.contains(shortName)) {
                                            emitLog("Package likely already installed (" + appId + "), asking for reinstall...", orange());
                                            m_pendingFlatpakAppId = appId;
                                            m_pendingFlatpakLocation = bundlePath;
                                            m_pendingFlatpakIsBundle = true;
                                            emit askReinstallFlatpak(appId);
                                            return;
                                        }
                                    }
                                }
                            }
                        }
                        emitLog("Installation failed with code " + QString::number(exitCode), "red");
                        emit hideKillPacmanButton();
                        emit showErrorDialog();
                    }
                });

        process->start("pkexec", fullArgs);
    }

    void runHelperSync(const QString &command, const QStringList &args)
    {
        QStringList fullArgs;
        fullArgs << helperPath() << command << args;
        QProcess process;
        process.start("pkexec", fullArgs);
        process.waitForFinished(-1);
        QString out = stripAnsi(QString::fromUtf8(process.readAllStandardOutput()).trimmed());
        QString err = stripAnsi(QString::fromUtf8(process.readAllStandardError()).trimmed());
        if (!out.isEmpty()) emitLog(out);
        if (!err.isEmpty()) emitLog(err, "red");
    }

    int similarityScore(const QString &a, const QString &b)
    {
        QString al = a.toLower(), bl = b.toLower();
        int maxLen = 0;
        for (int i = 0; i < al.length(); i++)
            for (int j = 0; j < bl.length(); j++) {
                int len = 0;
                while (i+len < al.length() && j+len < bl.length() && al[i+len] == bl[j+len]) len++;
                if (len > maxLen) maxLen = len;
            }
        return maxLen;
    }

    string normalizeExtractedDir(const string &extractedDir)
    {
        namespace fs = std::filesystem;
        if (!fs::exists(extractedDir) || fs::is_empty(extractedDir)) return extractedDir;
        vector<fs::directory_entry> entries;
        for (const auto &entry : fs::directory_iterator(extractedDir)) entries.push_back(entry);
        if (entries.size() == 1 && entries[0].is_directory()) return entries[0].path().string();
        return extractedDir;
    }

    QString archiveBaseName(const QString &archivePath)
    {
        QString name = QFileInfo(archivePath).fileName();
        for (const QString &ext : {".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tgz", ".zip"})
            if (name.endsWith(ext)) { name = name.left(name.length() - ext.length()); break; }
        name = name.split(QRegularExpression("[-_][0-9]")).first();
        return name;
    }

    QString execBaseName(const QString &filePath)
    {
        QString name = QFileInfo(filePath).fileName();
        if (name.endsWith(".sh")) name = name.left(name.length() - 3);
        name = name.split(QRegularExpression("[-_][0-9]")).first();
        return name;
    }

    void emitLog(const QString &msg, const QString &color = "default")
    {
        if (msg.isEmpty()) return;

        QString safe = msg;
        safe.replace("&", "&amp;");
        safe.replace("<", "&lt;");
        safe.replace(">", "&gt;");

        QString actualColor = (color == "default") ? "" : color;
        QString actualDefault = m_lightMode ? "#111111" : "white";
        QString line = actualColor.isEmpty() ? "<span style='color:" + actualDefault + "'>" + safe + "</span>" : "<span style='color:" + actualColor + "'>" + safe + "</span>";

        m_logBuffer.append(line);

        // Keep only the last 200 lines
        while (m_logBuffer.size() > 200)
            m_logBuffer.removeFirst();

        emit logMessage(line);
    }
    void emitProgressLog(const QString &msg, const bool timer)
    {
        if (!timer) {
            m_pendingProgressMsg = msg;
            flushProgressLog();
            return;
        }
        m_pendingProgressMsg = msg;
        qint64 now = QDateTime::currentMSecsSinceEpoch();

        if (now - m_lastProgressEmit >= 750) {
            flushProgressLog();
            return;
        }

        if (!m_progressFlushTimer) {
            m_progressFlushTimer = new QTimer(this);
            m_progressFlushTimer->setSingleShot(true);
            connect(m_progressFlushTimer, &QTimer::timeout, this, &Backend::flushProgressLog);
        }

        if (!m_progressFlushTimer->isActive()) {
            qint64 remaining = 750 - (now - m_lastProgressEmit);
            m_progressFlushTimer->start(static_cast<int>(qMax<qint64>(0, remaining)));
        }
    }

    void flushProgressLog()
    {
        if (m_installsuccess){
            return;
        }
        if (m_pendingProgressMsg.isEmpty()) return;

        m_lastProgressEmit = QDateTime::currentMSecsSinceEpoch();

        QString safe = m_pendingProgressMsg;
        safe.replace("&", "&amp;");
        safe.replace("<", "&lt;");
        safe.replace(">", "&gt;");

        QString styled = "<span style='color:" + greycolor() + "'>" + safe + "</span>";

        if (m_progressLogActive) {
            emit updateLastLogMessage(styled);
        } else {
            m_progressLogActive = true;
            m_logBuffer.append(styled);
            while (m_logBuffer.size() > 200)
                m_logBuffer.removeFirst();
            emit logMessage(styled);
        }

        m_pendingProgressMsg.clear();
    }
};

QString resolveFlatpakUri(const QString &uri)
{
    QString url = uri;
    url.remove(0, QString("flatpak+").length());

    QString tmpFile = QDir::tempPath() + "/packageinstaller-download.flatpakref";

    qDebug() << "Downloading flatpakref from:" << url;

    QProcess curl;
    curl.start("curl", {"-L", "-s", "-o", tmpFile, url});
    curl.waitForFinished(15000);

    if (curl.exitCode() != 0 || !QFileInfo::exists(tmpFile)) {
        qDebug() << "Download failed";
        return QString();
    }

    qDebug() << "Downloaded to:" << tmpFile;
    return tmpFile;
}

QTranslator *g_translator = nullptr;

void markTime(const char* label) {
    auto now = std::chrono::high_resolution_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - Backend::getStartTime()).count();
    std::ofstream f(std::string(getenv("HOME")) + "/Desktop/timing.txt", std::ios::app);
    f << ms << "ms — " << label << "\n";
}

// ─────────────────────────────────────────────
//  main
// ─────────────────────────────────────────────
bool g_reloading = false;
QSystemTrayIcon *g_trayIcon = nullptr;
QMenu *g_trayMenu = nullptr;

static QIcon trayIconForTheme()
{
    bool isDark = (qApp->styleHints()->colorScheme() == Qt::ColorScheme::Dark);
    return QIcon(isDark ? ":/logo/TrayIconDarkMode48.png"
                        : ":/logo/TrayIconLightMode48.png");
}

int main(int argc, char *argv[])
{
    // Fix for GNOME: Ensure native window decorations and proper theme
    if (qEnvironmentVariableIsSet("XDG_CURRENT_DESKTOP")) {
        QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP").toLower();
        if (desktop.contains("gnome") || desktop.contains("unity")) {
            qputenv("QT_QPA_PLATFORMTHEME", "gnome");
        }
    }
    QCoreApplication::setAttribute(Qt::AA_DontUseNativeMenuBar);



    QApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/logo/logo120.png"));
    app.setDesktopFileName("PackageInstaller");

    QSurfaceFormat format;
    format.setSamples(4);
    QSurfaceFormat::setDefaultFormat(format);
    app.setDesktopSettingsAware(true);

    // ── Parsing arguments ─────────────────────────────────────────────
    bool trayMode   = false;
    bool silentMode = false;
    bool noTrayCheck = false;
    QString filePathArg;

    for (int i = 1; i < argc; i++) {
        QString arg = QString::fromUtf8(argv[i]);
        qWarning() << "arg[" << i << "]=" << arg;
        if (arg == "--tray")               trayMode    = true;
        else if (arg == "--silent")        silentMode  = true;
        else if (arg == "--no-tray-check") noTrayCheck = true;
        else if (!arg.startsWith("--"))    filePathArg = arg;
    }
    qWarning() << "trayMode=" << trayMode << "noTrayCheck=" << noTrayCheck << "filePathArg=" << filePathArg;

    // ── Normalizing filePathArg ──────────────────────────────────────
    auto normalizeFilePath = [](QString path) -> QString {
        if (path.startsWith("file://"))
            path = QUrl(path).toLocalFile();
        else if (path.startsWith("flatpak+https://") || path.startsWith("flatpak+http://")) {
            path = resolveFlatpakUri(path);
        }
        while (path.endsWith("/") && path.length() > 1)
            path = path.left(path.length() - 1);
        return path;
    };

    if (!filePathArg.isEmpty()) {
        filePathArg = normalizeFilePath(filePathArg);
        if (filePathArg.isEmpty()) return 1;
    }

    // ── If noTrayCheck — check if we need to start in tray mode ──
    bool autostartEnabled = QFileInfo::exists(
        QDir::homePath() + "/.config/autostart/PackageInstaller.desktop");
    qWarning() << "noTrayCheck block: autostartEnabled=" << autostartEnabled;

    if (autostartEnabled) {
        QLocalSocket testSocket;
        testSocket.connectToServer(kSocketName);
        bool trayRunning = testSocket.waitForConnected(300);
        if (trayRunning) testSocket.disconnectFromServer();
        qWarning() << "trayRunning=" << trayRunning;

        if (!trayRunning) {
            trayMode = true;
            qWarning() << "switching to trayMode=true";
        }
    }

    if (!trayMode && !noTrayCheck) {
        QLocalSocket socket;
        socket.connectToServer(kSocketName);
        if (socket.waitForConnected(300)) {
            QString msg = filePathArg.isEmpty() ? "show" : ("open:" + filePathArg);
            socket.write(msg.toUtf8());
            socket.flush();
            socket.waitForBytesWritten(300);
            socket.disconnectFromServer();
            return 0;
        }
    }

    // ── Tray mode: starting LocalServer ────────────────────────────
    if (trayMode) {
        QLocalServer::removeServer(kSocketName);
        g_localServer = new QLocalServer(&app);
        g_localServer->listen(kSocketName);
    }

    // ── Translator ────────────────────────────────────────────────────
    g_translator = new QTranslator(&app);
    QString langCode;
    QString cfgPath = configDir() + "/language.txt";
    QFile cfgFile(cfgPath);
    if (cfgFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        langCode = QString::fromUtf8(cfgFile.readAll()).trimmed();
        cfgFile.close();
    }
    
    if (langCode.isEmpty()) {
        langCode = QLocale::system().name();
    }

    if (loadTranslator(g_translator, langCode)) {
        app.installTranslator(g_translator);
    }

    // ── Engine + Backend ──────────────────────────────────────────────
    QQmlApplicationEngine *engine = new QQmlApplicationEngine();
    Backend backend;
    engine->rootContext()->setContextProperty("backend", &backend);
    g_engine = engine;
    backend.initAiAccess();
    backend.rmAlltempfiles();

    QObject::connect(engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    QObject::connect(&backend, &Backend::reloadQmlRequested, engine, [engine]() {
        if (g_reloading) return;
        g_reloading = true;
        engine->clearComponentCache();
        const auto rootObjects = engine->rootObjects();
        for (auto obj : rootObjects) obj->deleteLater();
        QTimer::singleShot(100, engine, [engine]() {
            engine->loadFromModule("PackageInstaller", "Main");
            QTimer::singleShot(500, []() { g_reloading = false; });
        });
    });

    // ── Function to create a new window (for multi-instance) ───────────
    // Called both at first launch and at each IPC "open:"
    auto createNewWindow = [engine, &backend](const QString &filePath, bool silent) {
        QQmlComponent *component = new QQmlComponent(
            engine,
            QUrl("qrc:/qt/qml/PackageInstaller/Main.qml"),
            QQmlComponent::Asynchronous);

        QObject::connect(component, &QQmlComponent::statusChanged,
                         engine, [component, &backend, filePath, silent](QQmlComponent::Status status) {
                             if (status == QQmlComponent::Error) {
                                 qWarning() << "QML error:" << component->errorString();
                                 component->deleteLater();
                                 return;
                             }
                             if (status != QQmlComponent::Ready) return;

                             QObject *obj = component->create();
                             component->deleteLater();
                             if (!obj) return;

                             if (auto *win = qobject_cast<QWindow*>(obj)) {
                                 win->show();
                                 win->raise();
                                 win->requestActivate();
                             }

                             if (!filePath.isEmpty()) {
                                 QTimer::singleShot(0, &backend, [&backend, filePath, silent]() {
                                     if (silent)
                                         backend.installAPP(filePath);
                                     else
                                         emit backend.openFileRequested(filePath);
                                 });
                             }
                         });
    };

    // ── First launch ─────────────────────────────────────────────────
    // If filePathArg exists — open it after creating the first window
    if (!filePathArg.isEmpty()) {
        QObject::connect(engine, &QQmlApplicationEngine::objectCreated,
                         &app, [&backend, filePathArg, silentMode](QObject *obj, const QUrl &) {
                             if (!obj) return;
                             static bool fired = false;
                             if (fired) return;
                             fired = true;
                             if (silentMode)
                                 backend.installAPP(filePathArg);
                             else
                                 emit backend.openFileRequested(filePathArg);
                         }, Qt::QueuedConnection);
    }

    engine->loadFromModule("PackageInstaller", "Main");

    // ── Tray ──────────────────────────────────────────────────────────
    if (trayMode && QSystemTrayIcon::isSystemTrayAvailable()) {
        g_trayIcon = new QSystemTrayIcon(&app);
        g_trayIcon->setIcon(trayIconForTheme());
        g_trayIcon->setToolTip("Linux App Installer");

        QObject::connect(qApp->styleHints(), &QStyleHints::colorSchemeChanged,
                         g_trayIcon, [](Qt::ColorScheme) {
                             if (g_trayIcon) g_trayIcon->setIcon(trayIconForTheme());
                         });

        QMenu *trayMenu = new QMenu();
        QAction *showAction = trayMenu->addAction(QObject::tr("Open"));
        trayMenu->addSeparator();
        QAction *quitAction = trayMenu->addAction(QObject::tr("Quit"));

        QObject::connect(showAction, &QAction::triggered, engine, [engine]() {
            showMainWindow(engine);
        });

        QObject::connect(quitAction, &QAction::triggered, &app, []() {
            if (g_trayIcon) g_trayIcon->hide();
            QCoreApplication::quit();
        });

        QObject::connect(g_trayIcon, &QSystemTrayIcon::activated,
                         engine, [engine](QSystemTrayIcon::ActivationReason reason) {
                             if (reason != QSystemTrayIcon::Trigger) return;
                             const auto roots = engine->rootObjects();
                             if (roots.isEmpty()) return;
                             if (auto *win = qobject_cast<QWindow*>(roots.first())) {
                                 if (win->isVisible()) win->hide();
                                 else { win->show(); win->raise(); win->requestActivate(); }
                             }
                         });

        g_trayIcon->setContextMenu(trayMenu);
        g_trayIcon->show();

        // Hide main window when starting in tray mode
        QObject::connect(engine, &QQmlApplicationEngine::objectCreated,
                         &app, [](QObject *obj, const QUrl &) {
                             if (!obj) return;
                             static bool fired = false;
                             if (fired) return;
                             fired = true;
                             if (auto *win = qobject_cast<QWindow*>(obj)) win->hide();
                         }, Qt::QueuedConnection);
    }

    // ── IPC: handling incoming connections from new instances ─────────────
    if (g_localServer) {
        QObject::connect(g_localServer, &QLocalServer::newConnection,
                         engine, [engine, &backend]() {
                             QLocalSocket *client = g_localServer->nextPendingConnection();
                             QObject::connect(client, &QLocalSocket::readyRead,
                                              engine, [engine, client, &backend]() {
                                                  QString msg = QString::fromUtf8(client->readAll());
                                                  client->deleteLater();

                                                  qWarning() << "IPC received:" << msg;

                                                  bool hasVisibleWindow = false;
                                                  const auto roots = engine->rootObjects();
                                                  qWarning() << "rootObjects count:" << roots.size();
                                                  for (auto *r : roots) {
                                                      if (auto *win = qobject_cast<QWindow*>(r)) {
                                                          qWarning() << "window visible:" << win->isVisible() << "title:" << win->title();
                                                          if (win->isVisible()) {
                                                              hasVisibleWindow = true;
                                                              break;
                                                          }
                                                      }
                                                  }
                                                  qWarning() << "hasVisibleWindow:" << hasVisibleWindow;
                                                  

                                                  if (msg == "show") {
                                                      if (!hasVisibleWindow) {
                                                          // Window hidden — show
                                                          showMainWindow(engine);
                                                      } else {
                                                          // Window already open — start a new empty process
                                                          QProcess::startDetached(
                                                              QCoreApplication::applicationFilePath(),
                                                              {"--no-tray-check"});
                                                      }
                                                  } else if (msg.startsWith("open:")) {
                                                      QString path = msg.mid(5);
                                                      if (!hasVisibleWindow) {
                                                          showMainWindow(engine);
                                                          QTimer::singleShot(0, &backend, [&backend, path]() {
                                                              emit backend.openFileRequested(path);
                                                          });
                                                      } else {
                                                          QStringList args = {"--no-tray-check"};
                                                          if (!path.isEmpty()) args << path;
                                                          QProcess::startDetached(
                                                              QCoreApplication::applicationFilePath(), args);
                                                      }
                                                  }
                                              });
                         });
    }
    QObject::connect(&app, &QCoreApplication::aboutToQuit, engine, [engine]() {
        engine->clearComponentCache();
        delete engine;
    });

    return app.exec();
}

#include "main.moc"