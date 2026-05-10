<img src="https://raw.githubusercontent.com/Nazarchykushka/Linux-package-installer-converter/main/logo/logo120.png" width="100" align="left" hspace="16"/>

### Linux Package Installer/Converter

Arch Linux graphical open-source utility that helps you install `.deb`, `.rpm` and even tarball packages.

<br clear="left"/>

<br/>

<div align="center">

<a href="https://github.com/Nazarchykushka/Linux-package-installer-converter/releases/latest">
  <img src="https://img.shields.io/badge/-%E2%AC%87%EF%B8%8F%20%20Download%20Latest%20Release%20%20%E2%AC%87%EF%B8%8F-1793d1?style=for-the-badge&logoColor=white&labelColor=0d1117&color=9476FF" alt="Download Latest Release" height="52"/>
</a>

</div>

---

## How to Install

1. Run in terminal:
   ```bash
   sudo pacman -U packageinstaller.pkg.tar.zst
   ```
   (drag the downloaded package to the terminal)

2. Get an AI token and model with internet access for all functionality (recommended OpenRouter with `google/gemma-4-31b-it:free`, it's the best free model for this task)

3. Enter your AI token in the program settings

---

## Notes

- Without AI, if the program depends on some package and it is not installed, it will not launch!
- Works only on Arch; support for other popular distributions is planned in the future

---

## How the Program Works

<video src="https://github.com/Nazarchykushka/Linux-package-installer-converter/blob/main/logo/demonstration.mp4" autoplay muted playsinline width="100%"></video>

This video demonstrates what the program installation looks like.

It uses [debtap](https://github.com/helixarch/debtap) and rpmtap (modified debtap) scripts to convert Debian packages to Arch and install them, so you can later delete all installed packages (including tarballs) just with the `pacman` utility. The `.deb` and `.rpm` packages include dependency packages which are installed on their native distributions. But on Arch they have different names, so the [debtap](https://github.com/helixarch/debtap) author created logic to translate Debian packages to Arch, which does not always work correctly. The Linux Package Installer author decided to use AI to translate packages, which mostly works correctly. You need to enter your provider (for now) in settings. It is recommended to enter a model which has internet access. **This program supports [OpenRouter](https://openrouter.ai), [Hugging Face](https://huggingface.co), [Mistral](https://mistral.ai), [OpenAI](https://platform.openai.com), [Gemini](https://aistudio.google.com) tokens.** AI is also used for the description, program name (the program itself does it, but not always correctly) and category. You can still use the program without AI, but then you will need to enter dependencies manually.

---

## Required Packages

`python-openai`, `python-rapidfuzz`, `libarchive`, `flatpak`, `glib2`, `kirigami`, `qt6-svg`, `qt6-declarative`, `qt6-base`

- AI token and model with internet access for all functionality (recommended OpenRouter with `google/gemma-4-31b-it:free`, it's the best free model for this task)
- Arch-based Linux distribution

---

## If You Want to Build This Program by Yourself

**To build the program:**

1. Download the source code
2. Install `cmake`
3. Install `qt6-languageserver`, `qt6-tools`, `vulkan-devel` and the required packages
4. `mkdir /PackageInstaller/build/Desktop-Debug/`
5. `cd /PackageInstaller/build/Desktop-Debug/`
6. Run `cmake ../..`
7. Run `cmake --build PackageInstaller/build/Desktop-Debug/ --target all`

**To build the installer:**

1. Build the program
2. Install `extra-cmake-modules`
3. `cd PackageInstaller/`
4. Run `makepkg -f`

---

## Support

As the program is only in pre-release stage, the author does not accept any donations. But all the translations except Ukrainian, Russian and English were partially made by Gemini, so if you know other languages, you can suggest improvements in the Reddit discussion or suggest your language translation. You can download the reference translation file [here](#). To ensure it works, download the source code, add your `.ts` file to the `translations` folder and compile the program.

---

## How to Install

1. Run in terminal:
   ```bash
   sudo pacman -U
   ```
   (drag the downloaded package to the terminal)

2. Get an AI token and model with internet access for all functionality (recommended OpenRouter with `google/gemma-4-31b-it:free`, it's the best free model for this task)

3. Enter your AI token in the program settings

---

## Notes

- Without AI, if the program depends on some package and it is not installed, it will not launch!
- Works only on Arch; support for other popular distributions is planned in the future

---

## How the Program Works

<video src="https://github.com/Nazarchykushka/Linux-package-installer-converter/blob/main/logo/demonstration.mp4" autoplay muted playsinline width="100%"></video>

This video demonstrates what the program installation looks like.

It uses [debtap](https://github.com/helixarch/debtap) and rpmtap (modified debtap) scripts to convert Debian packages to Arch and install them, so you can later delete all installed packages (including tarballs) just with the `pacman` utility. The `.deb` and `.rpm` packages include dependency packages which are installed on their native distributions. But on Arch they have different names, so the [debtap](https://github.com/helixarch/debtap) author created logic to translate Debian packages to Arch, which does not always work correctly. The Linux Package Installer author decided to use AI to translate packages, which mostly works correctly. You need to enter your provider (for now) in settings. It is recommended to enter a model which has internet access. **This program supports [OpenRouter](https://openrouter.ai), [Hugging Face](https://huggingface.co), [Mistral](https://mistral.ai), [OpenAI](https://platform.openai.com), [Gemini](https://aistudio.google.com) tokens.** AI is also used for the description, program name (the program itself does it, but not always correctly) and category. You can still use the program without AI, but then you will need to enter dependencies manually.

---

## Required Packages

`python-openai`, `python-rapidfuzz`, `libarchive`, `flatpak`, `glib2`, `kirigami`, `qt6-svg`, `qt6-declarative`, `qt6-base`

- AI token and model with internet access for all functionality (recommended OpenRouter with `google/gemma-4-31b-it:free`, it's the best free model for this task)
- Arch-based Linux distribution

---

## If You Want to Build This Program by Yourself

**To build the program:**

1. Download the source code
2. Install `cmake`
3. Install `qt6-languageserver`, `qt6-tools`, `vulkan-devel` and the required packages
4. `mkdir /PackageInstaller/build/Desktop-Debug/`
5. `cd /PackageInstaller/build/Desktop-Debug/`
6. Run `cmake ../..`
7. Run `cmake --build PackageInstaller/build/Desktop-Debug/ --target all`

**To build the installer:**

1. Build the program
2. Install `extra-cmake-modules`
3. `cd PackageInstaller/`
4. Run `makepkg -f`

---

## Support

As the program is only in pre-release stage, the author does not accept any donations. But all the translations except Ukrainian, Russian and English were partially made by Gemini, so if you know other languages, you can suggest improvements in the Reddit discussion or suggest your language translation. You can download the reference translation file [here](#). To ensure it works, download the source code, add your `.ts` file to the `translations` folder and compile the program.
