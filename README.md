# Linux Package Installer/Converter
Arch linux graphical opensource utility that helps you to install .deb, .rpm and even tarboll packages.

Download // make this button centered with link to latest release download

**How to install**

  1. Run in terminal:  
    sudo pacman -U (and drag downloaded package to terminal)
  2. Get a AI token and model with internet access for all functionality (recommended OpenRouter with google/gemma-4-31b-it:free, it's the best free model in this task)
  3. Enter your AI token in program settings

**Notes**
   -Without AI if program depends on some package and it is not installed, it will not launch!
   -Works only on arch, support of other popular distributions are planned in future

**How the program works**

  This video demonstrates how the program installing looks
  
  It uses debtap /* make this work clickable with link https://github.com/helixarch/debtap */ and rpmtap (modified debtap) scripts to convert debian packages to arch and install so you can later delete all installed packages (including tarbols) just with pacman utility. The .deb and .rpm packages includes dependencies packages which are installing on their native distributions. But on arch they have different name, so the debtap /* make this work clickable with link https://github.com/helixarch/debtap */ author created logic to translate debian packages to arch which is not working propertly. LinuxPackageInstaller author decided to use AI to translate packages which mostly everytime works correct. You need to enter your provider (for now) in settings. It's recommended to enter model which has internet acess. *Bold* This program supports openRouter, huggingFace, Mistral, OpenAI, Gemini tokens. /* paste here link to sites of that providers */. Ai is also used for description, program name (The program itself does it, but not everytime correctly) and category. You still can use the program without ai, but than you will need to enter dependencies manually.

**Required packages**

  python-openai, python-rapidfuzz, libarchive, flatpak, glib2, kirigami, qt6-svg, qt6-declarative, qt6-base
  - AI token and model with internet access for all functionality (recommended OpenRouter with google/gemma-4-31b-it:free, it's the best free model in this task)
  - Arch based linux distribution

**If you want to build this program by yourself**

  - To build the program:
    1. Download source code
    2. Install cmake
    3. Install qt6-languageserver, qt6-tools, vulkan-devel and required packages
    4. mkdir /PackageInstaller/build/Desktop-Debug/
    5. cd /PackageInstaller/build/Desktop-Debug/
    6. Run cmake ../..
    7. Run cmake --build PackageInstaller/build/Desktop-Debug/ --target all
  - To build the installer
    1. Build the program
    2. install extra-cmake-modules
    3. cd PackageInstaller/
    4. Run makepkg -f
   
**Support**

  As the program is only in pre-release stage, the author do not accept any donations. But all the translations except ukrainian, russian and english were partially made by gemini, so if you know other languages, you can suggest on reddit discussion your improvments or suggest your language translation. You can download reference translation file here /* add here link */. To ensure it works, download source code, add your .ts file to translations folder and compile the program

