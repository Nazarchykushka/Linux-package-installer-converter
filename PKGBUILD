pkgname=packageinstaller
pkgver=0.1
pkgrel=8
pkgdesc="Package Installer (Progress bar & AlwaysShowConsole ON by default, Multi-lang)"
arch=('x86_64')
url="https://github.com/naz/PackageInstaller"
license=('GPL')
depends=('qt6-base' 'qt6-declarative' 'qt6-svg' 'kirigami' 'libarchive' 'flatpak' 'glib2' 'python-openai' 'python-rapidfuzz')
makedepends=('cmake' 'extra-cmake-modules' 'qt6-tools')
options=('!lto')
source=()

build() {
    cd "$startdir"
    cmake -B build_pkg -S . \
        -DCMAKE_INSTALL_PREFIX=/opt/packageinstaller \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build build_pkg
}

package() {
    cd "$startdir"
    
    # 1. Основна інсталяція
    DESTDIR="$pkgdir" cmake --install build_pkg

    # 3. Скрипти
    install -d "$pkgdir/opt/packageinstaller/scripts"
    install -m755 scripts/debtap "$pkgdir/opt/packageinstaller/scripts/"
    install -m755 scripts/rpmtap "$pkgdir/opt/packageinstaller/scripts/"
    install -m755 scripts/debtap-ai-translator.py "$pkgdir/opt/packageinstaller/scripts/"

    # 5. Symlinks
    install -d "$pkgdir/usr/bin"
    ln -s /opt/packageinstaller/bin/appPackageInstaller "$pkgdir/usr/bin/appPackageInstaller"
    ln -s /opt/packageinstaller/bin/packageinstaller-helper "$pkgdir/usr/bin/packageinstaller-helper"

    # 6. Іконка та ярлики
    install -Dm644 "logo/logo120.png" "$pkgdir/usr/share/icons/hicolor/128x128/apps/packageinstaller.png"
    install -d "$pkgdir/usr/share/applications"
    cat <<EOF > "$pkgdir/usr/share/applications/PackageInstaller.desktop"
[Desktop Entry]
Name=Linux Package Installer
Comment=Install packages with a single click
Exec=appPackageInstaller %u
Icon=packageinstaller
Type=Application
Categories=Qt;Utility;Settings;
MimeType=application/vnd.debian.binary-package;application/x-debian-package;application/x-rpm;application/vnd.flatpak;application/vnd.flatpak.ref;application/vnd.flatpak.repo;
Terminal=false
StartupNotify=true
EOF
    cp "$pkgdir/usr/share/applications/PackageInstaller.desktop" "$pkgdir/usr/share/applications/appPackageInstaller.desktop"
    echo "NoDisplay=true" >> "$pkgdir/usr/share/applications/appPackageInstaller.desktop"
}
