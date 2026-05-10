cmake_minimum_required(VERSION 3.16)
project(PackageInstaller VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Qt6
find_package(Qt6 REQUIRED COMPONENTS Quick Network LabsPlatform Widgets DBus LinguistTools)
qt_standard_project_setup(REQUIRES 6.2)

qt_add_executable(appPackageInstaller
    main.cpp
)

qt_add_resources(appPackageInstaller "logo"
    PREFIX "/logo"
    FILES
        logo/logo120.png
)

qt_add_qml_module(appPackageInstaller
    URI PackageInstaller
    VERSION 1.0
    QML_FILES
        Main.qml
    RESOURCES
        scripts/debtap-ai-translator.py
        scripts/debtap
        scripts/rpmtap

    RESOURCE_PREFIX "/qt/qml"
)

# Translations
file(GLOB TS_FILES translations/*.ts)
qt_add_translations(appPackageInstaller
    TS_FILES ${TS_FILES}
    RESOURCE_PREFIX "/i18n"
)

find_package(KF6Kirigami2 REQUIRED)
find_package(PkgConfig REQUIRED)

pkg_check_modules(LIBARCHIVE REQUIRED libarchive)
pkg_check_modules(FLATPAK    REQUIRED flatpak)

# ── Основний таргет ──────────────────────────────────────────────────────────
target_link_libraries(appPackageInstaller
    PRIVATE Qt6::Quick
    PRIVATE Qt6::Network
    PRIVATE Qt6::LabsPlatform
    PRIVATE Qt6::Widgets
    PRIVATE Qt6::DBus
    PRIVATE KF6::Kirigami2
    PRIVATE util
    PRIVATE ${LIBARCHIVE_LIBRARIES}
)
target_include_directories(appPackageInstaller
    PRIVATE ${LIBARCHIVE_INCLUDE_DIRS}
)

# ── Helper ───────────────────────────────────────────────────────────────────
add_executable(packageinstaller-helper
    packageinstaller-helper.cpp
)
target_compile_features(packageinstaller-helper PRIVATE cxx_std_17)

# Підключаємо flatpak і glib тільки до хелпера
target_include_directories(packageinstaller-helper
    PRIVATE ${FLATPAK_INCLUDE_DIRS}
)
target_link_libraries(packageinstaller-helper
    PRIVATE ${FLATPAK_LIBRARIES}
)
# glib потрібен для g_signal_connect, GError тощо
pkg_check_modules(GLIB REQUIRED glib-2.0)
target_include_directories(packageinstaller-helper
    PRIVATE ${GLIB_INCLUDE_DIRS}
)
target_link_libraries(packageinstaller-helper
    PRIVATE ${GLIB_LIBRARIES}
)

# ── Install ──────────────────────────────────────────────────────────────────
install(TARGETS appPackageInstaller
    BUNDLE  DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(TARGETS packageinstaller-helper
    DESTINATION bin
)
