#!/usr/bin/env python3
"""
debtap-ai-translator.py  (RPM + DEB edition)

Translates Debian *or* RPM package dependency names to Arch Linux package names
using local fuzzy search + OpenRouter API.

HOW IT WORKS:
  1. Check hard-coded KNOWN_MAPPINGS first (instant, no API call)
  2. Apply name-transform rules (libfoo0→libfoo, python3-foo→python-foo, etc.)
  3. Fuzzy-search arch-packages.txt to find ~6 candidates per package
  4. Send only those candidates to the AI — it picks the best one
  5. Validate the AI answer is actually in arch-packages.txt (safety net)

SETUP:
    pacman -Sl | awk '{print $2}' > arch-packages.txt
    Place arch-packages.txt alongside this script (or set ARCH_PACKAGES_FILE).
    pip install openai rapidfuzz

Usage:
    python3 debtap-ai-translator.py <api_key> <input_file> [output_file]

Exit codes:
    0 - success
    1 - usage error
    2 - missing dependency or file
"""

import sys
import json
import re
import os
import urllib.request

# NOTE: OpenAI SDK is only needed for the OpenRouter path.
# Gemini calls are done via urllib, so we keep this optional.
try:
    from openai import OpenAI  # type: ignore
except ImportError:
    OpenAI = None

try:
    from rapidfuzz import process as fuzz_process, fuzz
except ImportError:
    print("ERROR: rapidfuzz not installed. Run: pip install rapidfuzz", file=sys.stderr)
    sys.exit(2)

# Глобальний ключ для Gemini (заповнюється в translate_packages)
_current_api_key = ""


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
MAX_TOKENS          = 256
BATCH_SIZE          = 30
FUZZY_CANDIDATES    = 6
FUZZY_MIN_SCORE     = 45

# Читаємо з env (встановлюється з C++ Backend)
AI_PROVIDER = os.environ.get("AI_PROVIDER", "openrouter")
AI_MODEL    = os.environ.get("AI_MODEL", "").strip()
AI_TOKEN_ENV = os.environ.get("AI_TOKEN", "").strip()

# Дефолтні моделі якщо не задано
if AI_PROVIDER == "gemini":
    MODEL = AI_MODEL if AI_MODEL else "gemini-2.5-flash"
elif AI_PROVIDER == "mistral":
    MODEL = AI_MODEL if AI_MODEL else "mistral-small-latest"
elif AI_PROVIDER == "openai":
    MODEL = AI_MODEL if AI_MODEL else "gpt-4o-mini"
elif AI_PROVIDER == "huggingface":
    MODEL = AI_MODEL if AI_MODEL else "meta-llama/Llama-3.2-3B-Instruct"
else:
    MODEL = AI_MODEL if AI_MODEL else "google/gemma-4-31b-it:free"
if AI_PROVIDER != "gemini" and OpenAI is None:
    print("ERROR: openai package not installed. Run: pip install openai", file=sys.stderr)
    sys.exit(2)


SYSTEM_PROMPT = """\
You are an expert Arch Linux package maintainer.

For each Debian or RPM package name you receive, pick the best matching Arch Linux
package from the CANDIDATES list provided for that package.

Rules:
1. Return ONLY a JSON object — no markdown, no explanation, no code fences.
2. Keys are the original package names (exactly as given).
3. Values MUST be chosen from the candidates list for that package, or null
   if none of the candidates are a reasonable match.
4. NEVER invent a package name that is not in the candidates list.
5. Common Debian patterns:
   - libfoo-dev       → prefer the non-dev candidate (Arch bundles headers)
   - python3-foo      → python-foo
   - libfoo0/libfooN  → libfoo  (drop soname digit suffix)
   - libc6            → glibc
   - libstdc++6       → gcc-libs
   - libgcc-s1        → gcc-libs
   - zlib1g           → zlib
6. Common RPM patterns (Fedora/RHEL/openSUSE → Arch):
   - glibc            → glibc
   - libstdc++        → gcc-libs
   - gcc-c++          → gcc
   - libXXX-devel     → libXXX  (Arch bundles headers, no -devel split)
   - python3-foo      → python-foo
   - qt5-qtbase       → qt5-base
   - qt6-qtbase       → qt6-base
   - mesa-libGL       → libglvnd  (or mesa)
   - mesa-libEGL      → libglvnd
   - libgbm           → mesa
   - alsa-lib         → alsa-lib
   - pulseaudio-libs  → libpulse
   - gtk3             → gtk3
   - gtk2             → gtk2
   - glib2            → glib2
   - dbus-libs        → dbus
   - libX11           → libx11
   - libxcb           → libxcb
   - nspr             → nspr
   - nss              → nss
   - at-spi2-core     → at-spi2-core
   - atk              → atk
   - at-spi2-atk      → at-spi2-atk
   - cairo            → cairo
   - pango            → pango
   - gdk-pixbuf2      → gdk-pixbuf2
   - wayland-libs     → wayland
   - libdrm           → libdrm
   - freetype         → freetype2
   - openssl-libs     → openssl
   - curl-minimal/libcurl → curl
   - java-XX-openjdk  → jre-openjdk (or jdk-openjdk)
   - liberation-fonts → ttf-liberation
"""


# ---------------------------------------------------------------------------
# Hard-coded known mappings
# Covers both Debian (deb_*) and RPM (Fedora/RHEL/openSUSE) names.
# ---------------------------------------------------------------------------

KNOWN_MAPPINGS: dict[str, str | None] = {
    # ── Debian names ──────────────────────────────────────────────────────
    "libc6":                    "glibc",
    "libstdc++6":               "gcc-libs",
    "libgcc-s1":                "gcc-libs",
    "libgcc1":                  "gcc-libs",
    "libatomic1":               "gcc-libs",
    "zlib1g":                   "zlib",
    "libssl1.0.0":              "openssl",
    "libssl1.1":                "openssl",
    "libssl3":                  "openssl",
    "libssl-dev":               "openssl",
    "libcurl3":                 "curl",
    "libcurl4":                 "curl",
    "libcurl4-openssl-dev":     "curl",
    "libcurl4-gnutls-dev":      "curl",
    "libcurl3-gnutls":          "curl",
    "libcurl3-nss":             "curl",
    "libfreetype6":             "freetype2",
    "libfreetype-dev":          "freetype2",
    "libfreetype6-dev":         "freetype2",
    "libgbm1":                  "mesa",
    "libgbm-dev":               "mesa",
    "libpulse0":                "libpulse",
    "libpulse-dev":             "libpulse",
    "libasound2":               "alsa-lib",
    "libasound2-dev":           "alsa-lib",
    "libgtk-3-0":               "gtk3",
    "libgtk-3-dev":             "gtk3",
    "libgtk2.0-0":              "gtk2",
    "libgtk2.0-dev":            "gtk2",
    "libglib2.0-0":             "glib2",
    "libglib2.0-dev":           "glib2",
    "libdbus-1-3":              "dbus",
    "libdbus-1-dev":            "dbus",
    "libxcb1":                  "libxcb",
    "libxcb1-dev":              "libxcb",
    "libx11-6":                 "libx11",
    "libx11-dev":               "libx11",
    "libxext6":                 "libxext",
    "libxext-dev":              "libxext",
    "libxss1":                  "libxss",
    "libxi6":                   "libxi",
    "libxi-dev":                "libxi",
    "libxrandr2":               "libxrandr",
    "libxfixes3":               "libxfixes",
    "libxrender1":              "libxrender",
    "libxcomposite1":           "libxcomposite",
    "libxdamage1":              "libxdamage",
    "libnspr4":                 "nspr",
    "libnss3":                  "nss",
    "libnss3-dev":              "nss",
    "libatspi2.0-0":            "at-spi2-core",
    "libatk1.0-0":              "atk",
    "libatk-bridge2.0-0":       "at-spi2-atk",
    "libcairo2":                "cairo",
    "libcairo2-dev":            "cairo",
    "libpango-1.0-0":           "pango",
    "libpangocairo-1.0-0":      "pango",
    "libgdk-pixbuf2.0-0":       "gdk-pixbuf2",
    "libgdk-pixbuf2.0-dev":     "gdk-pixbuf2",
    "libwayland-client0":       "wayland",
    "libwayland-egl1":          "wayland",
    "libwayland-dev":           "wayland",
    "libegl1":                  "libglvnd",
    "libgl1":                   "libglvnd",
    "libgl1-mesa-glx":          "libglvnd",
    "libgles2":                 "libglvnd",
    "libdrm2":                  "libdrm",
    "libdrm-dev":               "libdrm",
    "default-jre":              "jre-openjdk",
    "default-jdk":              "jdk-openjdk",
    "default-jre-headless":     "jre-openjdk-headless",
    "desktop-file-utils":       "desktop-file-utils",
    "ibus":                     "ibus",
    "fonts-liberation":         "ttf-liberation",
    "fonts-freefont-ttf":       "ttf-freefont",

    # Debian t64 transition variants (common on newer Debian/Ubuntu)
    "libasound2t64":            "alsa-lib",
    "libatspi2.0-0t64":         "at-spi2-core",
    "libatk1.0-0t64":           "atk",
    "libatk-bridge2.0-0t64":    "at-spi2-atk",
    "libcairo2t64":             "cairo",
    "libcups2t64":              "libcups",
    "libdbus-1-3t64":           "dbus",
    "libexpat1t64":             "expat",
    "libgbm1t64":               "mesa",
    "libglib2.0-0t64":          "glib2",
    "libgtk-3-0t64":            "gtk3",
    "libgtk-4-1t64":            "gtk4",
    "libnspr4t64":              "nspr",
    "libnss3t64":               "nss",
    "libx11-6t64":              "libx11",
    "libxcb1t64":               "libxcb",
    "libxcomposite1t64":        "libxcomposite",
    "libxdamage1t64":           "libxdamage",
    "libxext6t64":              "libxext",
    "libxfixes3t64":            "libxfixes",
    "libxrandr2t64":            "libxrandr",
    "libxkbcommon0t64":         "libxkbcommon",
    "libxkbfile1t64":           "libxkbfile",

    # Debian "ABI name" packages without t64 suffix
    "libexpat1":                "expat",
    "libcups2":                 "libcups",
    "libgtk-4-1":               "gtk4",
    "libudev1":                 "systemd-libs",

    # ── RPM names (Fedora / RHEL / CentOS / openSUSE / Mageia) ───────────

    # Core C runtime & compiler libs
    "glibc":                    "glibc",
    "glibc-common":             "glibc",
    "glibc-devel":              "glibc",
    "libstdc++":                "gcc-libs",
    "libstdc++-devel":          "gcc",
    "libgcc":                   "gcc-libs",
    "libatomic":                "gcc-libs",
    "gcc":                      "gcc",
    "gcc-c++":                  "gcc",
    "binutils":                 "binutils",

    # zlib / compression
    "zlib":                     "zlib",
    "zlib-devel":               "zlib",
    "bzip2-libs":               "bzip2",
    "bzip2-devel":              "bzip2",
    "xz-libs":                  "xz",
    "xz-devel":                 "xz",
    "lz4-libs":                 "lz4",
    "zstd-libs":                "zstd",
    "libzstd":                  "zstd",
    "libzstd-devel":            "zstd",

    # SSL / crypto
    "openssl-libs":             "openssl",
    "openssl-devel":            "openssl",
    "openssl":                  "openssl",
    "libssl1_1":                "openssl",
    "libssl-devel":             "openssl",
    "mozilla-nss":              "nss",
    "mozilla-nspr":             "nspr",
    "nspr":                     "nspr",
    "nss":                      "nss",
    "nss-devel":                "nss",

    # curl
    "libcurl":                  "curl",
    "libcurl-devel":            "curl",
    "libcurl-minimal":          "curl",
    "curl":                     "curl",

    # freetype / fontconfig / harfbuzz
    "freetype":                 "freetype2",
    "freetype-devel":           "freetype2",
    "libfreetype6":             "freetype2",
    "fontconfig":               "fontconfig",
    "fontconfig-devel":         "fontconfig",
    "harfbuzz":                 "harfbuzz",
    "harfbuzz-devel":           "harfbuzz",

    # Graphics / Mesa / GL
    "mesa-libGL":               "libglvnd",
    "mesa-libGL-devel":         "libglvnd",
    "mesa-libEGL":              "libglvnd",
    "mesa-libEGL-devel":        "libglvnd",
    "mesa-libGLES":             "libglvnd",
    "mesa-libgbm":              "mesa",
    "mesa-libgbm-devel":        "mesa",
    "mesa-dri-drivers":         "mesa",
    "mesa":                     "mesa",
    "libGL":                    "libglvnd",
    "libEGL1":                  "libglvnd",
    "libglvnd":                 "libglvnd",
    "libglvnd-glx":             "libglvnd",
    "libglvnd-egl":             "libglvnd",
    "libglvnd-devel":           "libglvnd",
    "libdrm":                   "libdrm",
    "libdrm-devel":             "libdrm",
    "libva":                    "libva",
    "libva-devel":              "libva",

    # Wayland
    "wayland-libs":             "wayland",
    "wayland-devel":            "wayland",
    "libwayland-client":        "wayland",
    "libwayland-server":        "wayland",
    "wayland-protocols-devel":  "wayland-protocols",

    # X11 / XCB / Xlib
    "libX11":                   "libx11",
    "libX11-devel":             "libx11",
    "libX11-common":            "libx11",
    "libXext":                  "libxext",
    "libXext-devel":            "libxext",
    "libXss":                   "libxss",
    "libXScrnSaver":            "libxss",
    "libXi":                    "libxi",
    "libXi-devel":              "libxi",
    "libXrandr":                "libxrandr",
    "libXrandr-devel":          "libxrandr",
    "libXfixes":                "libxfixes",
    "libXrender":               "libxrender",
    "libXcomposite":            "libxcomposite",
    "libXdamage":               "libxdamage",
    "libxcb":                   "libxcb",
    "libxcb-devel":             "libxcb",
    "xcb-util":                 "xcb-util",
    "xcb-util-devel":           "xcb-util",
    "libxkbcommon":             "libxkbcommon",
    "libxkbcommon-devel":       "libxkbcommon",
    "libxkbcommon-x11":         "libxkbcommon-x11",

    # Audio
    "alsa-lib":                 "alsa-lib",
    "alsa-lib-devel":           "alsa-lib",
    "pulseaudio-libs":          "libpulse",
    "pulseaudio-libs-devel":    "libpulse",
    "pipewire-libs":            "pipewire",
    "pipewire-alsa":            "pipewire-alsa",
    "pipewire-pulseaudio":      "pipewire-pulse",

    # GTK / GLib / GDK / ATK
    "gtk3":                     "gtk3",
    "gtk3-devel":               "gtk3",
    "gtk2":                     "gtk2",
    "gtk2-devel":               "gtk2",
    "gtk4":                     "gtk4",
    "gtk4-devel":               "gtk4",
    "glib2":                    "glib2",
    "glib2-devel":              "glib2",
    "gdk-pixbuf2":              "gdk-pixbuf2",
    "gdk-pixbuf2-devel":        "gdk-pixbuf2",
    "cairo":                    "cairo",
    "cairo-devel":              "cairo",
    "pango":                    "pango",
    "pango-devel":              "pango",
    "atk":                      "atk",
    "atk-devel":                "atk",
    "at-spi2-core":             "at-spi2-core",
    "at-spi2-atk":              "at-spi2-atk",
    "at-spi2-core-devel":       "at-spi2-core",

    # D-Bus
    "dbus-libs":                "dbus",
    "dbus":                     "dbus",
    "dbus-devel":               "dbus",
    "dbus-common":              "dbus",

    # Qt 5
    "qt5-qtbase":               "qt5-base",
    "qt5-qtbase-gui":           "qt5-base",
    "qt5-qtbase-devel":         "qt5-base",
    "qt5-qtwebengine":          "qt5-webengine",
    "qt5-qtsvg":                "qt5-svg",
    "qt5-qtx11extras":          "qt5-x11extras",
    "qt5-qtdeclarative":        "qt5-declarative",
    "qt5-qttools":              "qt5-tools",

    # Qt 6
    "qt6-qtbase":               "qt6-base",
    "qt6-qtbase-gui":           "qt6-base",
    "qt6-qtbase-devel":         "qt6-base",
    "qt6-qtwebengine":          "qt6-webengine",
    "qt6-qtsvg":                "qt6-svg",
    "qt6-qtdeclarative":        "qt6-declarative",

    # Python
    "python3":                  "python",
    "python3-devel":            "python",
    "python3-libs":             "python",
    "python":                   "python",
    "python-devel":             "python",
    "python3-pip":              "python-pip",
    "python3-setuptools":       "python-setuptools",

    # Java
    "java-latest-openjdk":      "jdk-openjdk",
    "java-latest-openjdk-headless": "jre-openjdk-headless",
    "java-17-openjdk":          "jdk17-openjdk",
    "java-17-openjdk-headless": "jre17-openjdk-headless",
    "java-11-openjdk":          "jdk11-openjdk",
    "java-11-openjdk-headless": "jre11-openjdk-headless",
    "java-1.8.0-openjdk":       "jdk8-openjdk",

    # Misc common deps
    "desktop-file-utils":       "desktop-file-utils",
    "ibus":                     "ibus",
    "liberation-fonts":         "ttf-liberation",
    "liberation-fonts-common":  "ttf-liberation",
    "google-noto-fonts-common": "noto-fonts",
    "sqlite":                   "sqlite",
    "sqlite-devel":             "sqlite",
    "sqlite-libs":              "sqlite",
    "expat":                    "expat",
    "expat-devel":              "expat",
    "pcre":                     "pcre",
    "pcre-devel":               "pcre",
    "pcre2":                    "pcre2",
    "pcre2-devel":              "pcre2",
    "readline":                 "readline",
    "readline-devel":           "readline",
    "ncurses":                  "ncurses",
    "ncurses-devel":            "ncurses",
    "ncurses-libs":             "ncurses",
    "bash":                     "bash",
    "coreutils":                "coreutils",
    "findutils":                "findutils",
    "grep":                     "grep",
    "sed":                      "sed",
    "gawk":                     "gawk",
    "systemd":                  "systemd",
    "systemd-libs":             "systemd-libs",
    "dconf":                    "dconf",
    "krb5-libs":                "krb5",
    "krb5-devel":               "krb5",
    "libsecret":                "libsecret",
    "libsecret-devel":          "libsecret",
    "libnotify":                "libnotify",
    "libnotify-devel":          "libnotify",
    "libuuid":                  "util-linux-libs",
    "libuuid-devel":            "util-linux-libs",
    "libblkid":                 "util-linux-libs",
    "libblkid-devel":           "util-linux-libs",
    "libnl3":                   "libnl",
    "libnl3-devel":             "libnl",
    "lsof":                     "lsof",
    "file-libs":                "file",
    "libjpeg-turbo":            "libjpeg-turbo",
    "libjpeg-turbo-devel":      "libjpeg-turbo",
    "libpng":                   "libpng",
    "libpng-devel":             "libpng",
    "libtiff":                  "libtiff",
    "libtiff-devel":            "libtiff",
    "libwebp":                  "libwebp",
    "libwebp-devel":            "libwebp",
    "libvorbis":                "libvorbis",
    "libvorbis-devel":          "libvorbis",
    "opus":                     "opus",
    "opus-devel":               "opus",
    "flac-libs":                "flac",
    "libogg":                   "libogg",
    "libogg-devel":             "libogg",
    "ffmpeg-libs":              "ffmpeg",
    "ffmpeg-free":              "ffmpeg",
    "gstreamer1":               "gstreamer",
    "gstreamer1-devel":         "gstreamer",
    "gstreamer1-plugins-base":  "gst-plugins-base",
    "gstreamer1-plugins-good":  "gst-plugins-good",
    "mpg123-libs":              "mpg123",
    "NetworkManager-libnm":     "networkmanager",
    "libicu":                   "icu",
    "libicu-devel":             "icu",

    # Vulkan
    "vulkan-loader":            "vulkan-icd-loader",
    "libvulkan1":               "vulkan-icd-loader",
    "libvulkan-dev":            "vulkan-headers",
    "vulkan-tools":             "vulkan-tools",
}


# ---------------------------------------------------------------------------
# Name transform: generate candidate seeds for fuzzy search
# Handles both Debian and RPM naming conventions.
# ---------------------------------------------------------------------------

def debian_to_arch_seeds(pkg_name: str) -> list[str]:
    name = pkg_name.lower().strip()
    candidates = {name}

    # Debian t64 transition (e.g. libglib2.0-0t64) → drop trailing t64
    if name.endswith("t64"):
        base = name[:-3]
        if base:
            candidates.add(base)

    # python3-foo → python-foo  (both Debian and Fedora use this)
    if name.startswith("python3-"):
        candidates.add("python-" + name[8:])

    # RPM -devel → strip suffix (Arch bundles headers in main package)
    if name.endswith("-devel"):
        base = name[:-6]
        candidates.add(base)
        # libfoo-devel → libfoo
        candidates.update(debian_to_arch_seeds(base))

    # Debian -dev → strip suffix
    if name.endswith("-dev"):
        base = name[:-4]
        candidates.add(base)

    # libfoo0 / libfoo2 / libfoo64 → libfoo  (Debian soname suffix)
    stripped = re.sub(r'[-_]?\d+(\.\d+)*$', '', name)
    if stripped and stripped != name:
        candidates.add(stripped)

    # Debian libfoo1.0-0 style → libfoo (strip ABI-ish tail)
    stripped3 = re.sub(r'\d+(\.\d+)*-\d+$', '', name)
    if stripped3 and stripped3 != name:
        candidates.add(stripped3)

    # libfoo-1-0 style → libfoo
    stripped2 = re.sub(r'[-_]\d+[-_]\d+$', '', name)
    if stripped2 != name:
        candidates.add(stripped2)

    # RPM: libfoo-libs → libfoo
    if name.endswith("-libs"):
        candidates.add(name[:-5])

    # RPM: libfoo-common → libfoo
    if name.endswith("-common"):
        candidates.add(name[:-7])

    # RPM mesa-libXXX → libXXX (lower-case), e.g. mesa-libGL → libgl (then fuzzy)
    if name.startswith("mesa-lib"):
        candidates.add("lib" + name[8:].lower())
        candidates.add("lib" + name[8:])

    # RPM qt5-qtfoo → qt5-foo
    m = re.match(r'^(qt[56])-qt(.+)$', name)
    if m:
        candidates.add(f"{m.group(1)}-{m.group(2)}")

    # fonts-* / *-fonts → ttf-* / otf-*
    if name.startswith("fonts-"):
        candidates.add("ttf-" + name[6:])
        candidates.add("otf-" + name[6:])
    if name.endswith("-fonts"):
        candidates.add("ttf-" + name[:-6])
        candidates.add(name[:-6] + "-fonts")

    return [c for c in candidates if c]


# ---------------------------------------------------------------------------
# Package list loader
# ---------------------------------------------------------------------------

def load_arch_packages() -> list[str]:
    search_paths = []
    env_path = os.environ.get("ARCH_PACKAGES_FILE")
    if env_path:
        search_paths.append(env_path)

    config_dir = os.path.expanduser("~/.cache/LinuxAppInstallerConfig")
    search_paths.append(os.path.join(config_dir, "arch-packages.txt"))

    script_dir = os.path.dirname(os.path.realpath(__file__))
    search_paths.append(os.path.join(script_dir, "arch-packages.txt"))
    search_paths.append(os.path.join(os.getcwd(), "arch-packages.txt"))

    for path in search_paths:
        if os.path.isfile(path):
            with open(path) as f:
                packages = [line.strip().lower() for line in f if line.strip()]
            print(f"   :: Loaded {len(packages):,} Arch packages", file=sys.stderr)
            return packages

    print(
        "ERROR: arch-packages.txt not found.\n"
        "Generate it with:  pacman -Sl | awk '{print $2}' > arch-packages.txt",
        file=sys.stderr,
    )
    sys.exit(2)


# ---------------------------------------------------------------------------
# Fuzzy search
# ---------------------------------------------------------------------------

def find_candidates(pkg_name: str, arch_packages: list[str], arch_set: set[str]) -> list[str]:
    seeds = debian_to_arch_seeds(pkg_name)

    exact = [s for s in seeds if s in arch_set]

    all_hits: dict[str, float] = {}
    for seed in seeds:
        hits = fuzz_process.extract(
            seed, arch_packages,
            scorer=fuzz.token_sort_ratio,
            limit=FUZZY_CANDIDATES,
            score_cutoff=FUZZY_MIN_SCORE,
        )
        for pkg, score, _ in hits:
            if pkg not in all_hits or all_hits[pkg] < score:
                all_hits[pkg] = score

    fuzzy_sorted = [pkg for pkg, _ in sorted(all_hits.items(), key=lambda x: x[1], reverse=True)]

    result = list(dict.fromkeys(exact + fuzzy_sorted))
    return result[:FUZZY_CANDIDATES]


# ---------------------------------------------------------------------------
# API call
# ---------------------------------------------------------------------------

def call_api_gemini(api_key: str, batch: list[tuple]) -> dict:
    lines = []
    for pkg_name, candidates in batch:
        cand_str = ", ".join(candidates) if candidates else "none"
        lines.append(f"{pkg_name}  [candidates: {cand_str}]")

    user_msg = SYSTEM_PROMPT + "\n\nTranslate these packages to Arch Linux:\n" + "\n".join(lines)

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={api_key}"
    payload = json.dumps({
        "contents": [{"role": "user", "parts": [{"text": user_msg}]}],
        "generationConfig": {"temperature": 0.0, "maxOutputTokens": 512},
    }).encode()

    try:
        req = urllib.request.Request(url, data=payload,
                                     headers={"Content-Type": "application/json"},
                                     method="POST")
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"ERROR: Gemini API HTTP {e.code}: {body[:300]}", file=sys.stderr)
        if e.code in (400, 401, 403):
            print("AUTH_ERROR_DETECTED", file=sys.stderr)
            sys.exit(4)
        return {}
    except Exception as e:
        print(f"ERROR: Gemini API call failed: {e}", file=sys.stderr)
        return {}

    try:
        raw = data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError):
        print(f"ERROR: Unexpected Gemini response structure", file=sys.stderr)
        return {}

    raw = re.sub(r'^```[a-z]*\n?', '', raw)
    raw = re.sub(r'\n?```$', '', raw)
    start, end = raw.find('{'), raw.rfind('}')
    if start != -1 and end != -1:
        raw = raw[start:end+1]
    raw = raw.strip()

    try:
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError("not a JSON object")
        return result
    except (json.JSONDecodeError, ValueError) as e:
        print(f"WARNING: Could not parse Gemini response: {e}\nRaw: {raw}", file=sys.stderr)
        return {}


def call_api(client, batch: list[tuple]) -> dict:
    if AI_PROVIDER == "gemini":
        return call_api_gemini(_current_api_key, batch)

    lines = []
    for pkg_name, candidates in batch:
        cand_str = ", ".join(candidates) if candidates else "none"
        lines.append(f"{pkg_name}  [candidates: {cand_str}]")

    user_msg = "Translate these packages to Arch Linux:\n" + "\n".join(lines)

    try:
        kwargs = {
            "model": MODEL,
            "max_tokens": MAX_TOKENS,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": user_msg},
            ],
            "temperature": 0.0,
        }
        if AI_PROVIDER not in ("mistral", "openai", "huggingface"):
            kwargs["extra_headers"] = {
                "HTTP-Referer": "https://github.com/helixarch/debtap",
                "X-OpenRouter-Title": "debtap-ai",
            }
        response = client.chat.completions.create(**kwargs)
    except Exception as e:
        err_str = str(e).lower()
        print(f"ERROR: API call failed: {e}", file=sys.stderr)
        if ("401" in err_str or "authentication" in err_str or
                "auth" in err_str or "invalid api key" in err_str or
                "unauthorized" in err_str or
                type(e).__name__ in ("AuthenticationError", "PermissionDeniedError")):
            print("AUTH_ERROR_DETECTED", file=sys.stderr)
            sys.exit(4)
        return {}

    if not response.choices or response.choices[0].message.content is None:
        print(f"WARNING: Empty response from AI", file=sys.stderr)
        return {}
    raw = response.choices[0].message.content.strip()

    try:
        maybe_err = json.loads(raw)
        if isinstance(maybe_err, dict) and "error" in maybe_err:
            err_code = maybe_err["error"].get("code", 0)
            err_msg  = maybe_err["error"].get("message", "")
            print(f"ERROR: API error in response body: {err_msg}", file=sys.stderr)
            if err_code in (401, 403) or "auth" in err_msg.lower() or "invalid" in err_msg.lower():
                sys.exit(4)
            return {}
    except (json.JSONDecodeError, TypeError):
        pass

    raw = re.sub(r'^```[a-z]*\n?', '', raw)
    raw = re.sub(r'\n?```$',       '', raw)
    raw = raw.strip()

    try:
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError("not a JSON object")
        return result
    except (json.JSONDecodeError, ValueError) as e:
        print(f"WARNING: Could not parse API response: {e}", file=sys.stderr)
        print(f"Raw response:\n{raw}", file=sys.stderr)
        return {}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_dep_line(line: str):
    line = line.strip()
    line = re.sub(r'[()]', '', line)
    m = re.match(r'^([^\s>=<!]+)\s*(>=|<=|=|>>|<<|>|<)?\s*(.*)$', line)
    if not m:
        return line, None, None
    name = m.group(1).strip()
    op   = (m.group(2) or "").strip() or None
    ver  = (m.group(3) or "").strip() or None
    if op == ">>": op = ">"
    if op == "<<": op = "<"
    return name, op, ver


def clean_version(ver: str) -> str:
    if not ver:
        return ver
    ver = re.sub(r'^\d+:', '', ver)
    ver = re.sub(r'-[^-]*$', '', ver)
    ver = re.sub(r'\.(fc|el|mga|suse|mdv|pclos|alt|omv|lp)\d+.*$', '', ver)
    return ver


# ---------------------------------------------------------------------------
# Main translation logic
# ---------------------------------------------------------------------------

def translate_packages(api_key: str, input_lines: list, arch_packages: list) -> list:
    global _current_api_key
    _current_api_key = api_key
    arch_set = set(arch_packages)

    if AI_PROVIDER == "gemini":
        client = None
    elif AI_PROVIDER in ("mistral", "openai", "huggingface"):
        # Використовуємо правильний base_url для кожного провайдера
        base_urls = {
            "mistral":     "https://api.mistral.ai/v1",
            "openai":      "https://api.openai.com/v1",
            "huggingface": "https://router.huggingface.co/v1",
        }
        client = OpenAI(base_url=base_urls[AI_PROVIDER], api_key=api_key)
    else:
        client = OpenAI(base_url=OPENROUTER_BASE_URL, api_key=api_key)

    parsed = []
    for line in input_lines:
        line = line.strip()
        if not line:
            parsed.append(("", None, None, ""))
            continue
        name, op, ver = parse_dep_line(line)
        parsed.append((name, op, ver, line))

    unique_names = list(dict.fromkeys(
        name for name, *_ in parsed if name
    ))

    translation_map: dict[str, str | None] = {}

    # Pass 1: known mappings
    need_lookup = []
    for name in unique_names:
        key = name.lower()
        if key in arch_set:
            translation_map[name] = key
            print(f"   :: {name} → {key}  (already arch)", file=sys.stderr)
            continue
        if key in KNOWN_MAPPINGS:
            # Always trust KNOWN_MAPPINGS — they are manually curated.
            # Do NOT gate on arch_set: the user's arch-packages.txt may be
            # out of date or from a derivative distro (CachyOS, Manjaro, etc.)
            # where some package names differ slightly.
            arch_name = KNOWN_MAPPINGS[key]
            translation_map[name] = arch_name
            print(f"   :: {name} → {arch_name}  (known)", file=sys.stderr)
        else:
            need_lookup.append(name)

    # Pass 2: fuzzy search + AI
    if need_lookup:

        need_ai: list[tuple[str, list[str]]] = []

        for name in need_lookup:
            candidates = find_candidates(name, arch_packages, arch_set)

            if not candidates:
                print(f"   :: {name} → no candidates, skipping", file=sys.stderr)
                translation_map[name] = None
                continue

            if len(candidates) == 1 and candidates[0] in arch_set:
                translation_map[name] = candidates[0]
                print(f"   :: {name} → {candidates[0]}  (fuzzy exact)", file=sys.stderr)
                continue

            print(f"   :: {name}  candidates: {', '.join(candidates)}", file=sys.stderr)
            need_ai.append((name, candidates))

        if need_ai:
            print(f"   :: Calling AI for {len(need_ai)} package(s)...", file=sys.stderr)
            for i in range(0, len(need_ai), BATCH_SIZE):
                chunk = need_ai[i:i + BATCH_SIZE]
                result = call_api(client, chunk)
                if not result:
                    for single_name, single_candidates in chunk:
                        single_result = call_api(client, [(single_name, single_candidates)])
                        if single_result:
                            result.update(single_result)

                for name, candidates in chunk:
                    ai_answer = result.get(name)
                    if not ai_answer:
                        translation_map[name] = None
                        continue

                    base = re.split(r'[><=]', ai_answer)[0].strip().lower()

                    if base in arch_set:
                        translation_map[name] = ai_answer
                        print(f"   :: {name} → {ai_answer}  (AI)", file=sys.stderr)
                    else:
                        print(
                            f"   :: WARNING: AI suggested '{ai_answer}' for '{name}' "
                            f"— not in arch-packages.txt, ignoring",
                            file=sys.stderr,
                        )
                        translation_map[name] = None

    # Build output lines
    # IMPORTANT: if a package could not be translated (arch_name is None),
    # write an empty line so the bash _apply_translation correctly counts it
    # as "failed" instead of keeping the original Debian/RPM name as a dependency.
    output_lines = []
    for name, op, ver, original in parsed:
        if not name:
            output_lines.append("")
            continue

        arch_name = translation_map.get(name)

        if not arch_name:
            # Write empty line — bash sees empty trans_name and marks as untranslated
            output_lines.append("")
            continue

        if re.search(r'[><=]', arch_name):
            output_lines.append(arch_name)
        elif op and ver:
            output_lines.append(f"{arch_name}{op}{clean_version(ver)}")
        else:
            output_lines.append(arch_name)

    return output_lines


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 3:
        print(
            f"Usage: {sys.argv[0]} <api_key> <input_file> [output_file]\n\n"
            "Setup:\n"
            "  pacman -Sl | awk '{print $2}' > arch-packages.txt\n"
            "  pip install openai rapidfuzz",
            file=sys.stderr,
        )
        sys.exit(1)

    api_key    = sys.argv[1]
    input_path = sys.argv[2]
    out_path   = sys.argv[3] if len(sys.argv) > 3 else None

    if not os.path.isfile(input_path):
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    if AI_TOKEN_ENV:
        api_key = AI_TOKEN_ENV
    elif not api_key or api_key.strip() in ("", "skip", "none", "null", "<OPENROUTER_API_KEY>"):
        config_dir = os.path.expanduser("~/.cache/LinuxAppInstallerConfig")
        if AI_PROVIDER == "gemini":
            token_file = os.path.join(config_dir, "gemini_token.txt")
        elif AI_PROVIDER == "openai":
            token_file = os.path.join(config_dir, "openai_token.txt")
        elif AI_PROVIDER == "huggingface":
            token_file = os.path.join(config_dir, "huggingface_token.txt")
        elif AI_PROVIDER == "mistral":
            token_file = os.path.join(config_dir, "mistral_token.txt")
        else:
            token_file = os.path.join(config_dir, "token.txt")
        token_file = os.path.join(config_dir, "token.txt")
        if os.path.isfile(token_file):
            with open(token_file) as f:
                api_key = f.read().strip()
            print(f"   :: Loaded token from {token_file}", file=sys.stderr)

    skip_ai = (
        not api_key
        or api_key.strip() in ("", "skip", "none", "null", "<OPENROUTER_API_KEY>")
        or os.environ.get("SKIP_AI") == "1"
    )

    with open(input_path) as f:
        input_lines = f.read().splitlines()

    if skip_ai:
        print("   :: No API key — skipping AI translation, using original dep names", file=sys.stderr)
        output_text = "\n".join(input_lines) + ("\n" if input_lines else "")
        if out_path:
            with open(out_path, "w") as f:
                f.write(output_text)
        else:
            sys.stdout.write(output_text)
        return

    arch_packages = load_arch_packages()

    if not arch_packages:
        config_dir = os.path.expanduser("~/.cache/LinuxAppInstallerConfig")
        arch_pkg_file = os.path.join(config_dir, "arch-packages.txt")
        if os.path.isfile(arch_pkg_file):
            os.environ["ARCH_PACKAGES_FILE"] = arch_pkg_file
            arch_packages = load_arch_packages()

    translated = translate_packages(api_key, input_lines, arch_packages)

    output_text = "\n".join(translated) + ("\n" if translated else "")

    if out_path:
        with open(out_path, "w") as f:
            f.write(output_text)
    else:
        sys.stdout.write(output_text)

if __name__ == "__main__":
    main()
