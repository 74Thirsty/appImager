# **appImager**

![GADGET SAAVY banner](https://raw.githubusercontent.com/74Thirsty/74Thirsty/main/assets/banner.svg)

## 🔧 Technologies & Tools

[![Cyfrin](https://img.shields.io/badge/Cyfrin-Audit%20Ready-005030?logo=shield&labelColor=F47321)](https://www.cyfrin.io/)
[![Python](https://img.shields.io/badge/Python-3.11-003057?logo=python&labelColor=B3A369)](https://www.python.org/)
[![pYcHARM](https://img.shields.io/badge/Built%20with-PyCharm-782F40?logo=pycharm&logoColor=CEB888)](https://www.jetbrains.com/pycharm/)
[![Issues](https://img.shields.io/github/issues/74Thirsty/appImager.svg?color=hotpink&labelColor=brightgreen)](https://github.com/74Thirsty/appImager/issues)
[![Security](https://img.shields.io/badge/encryption-AES--256-orange.svg?color=13B5EA&labelColor=9EA2A2)]()

> <p><strong>Christopher Hirschauer</strong><br>
> Builder @ the bleeding edge of MEV, automation, and high-speed arbitrage.<br>
<em>June 13, 2025</em></p>



* Runs on most modern Linux distros without installation.
* Keeps your app as a single file — easy to send or host.
* Double-clickable in most file managers.
* No root needed.
* Can bundle your dependencies so users don’t need to install anything.


# AppImager

`AppImager` is a lightweight interactive script for packaging your own applications, scripts, or binaries into [AppImage](https://appimage.org/) bundles.  
It asks for key details (name, version, executable path, optional icon) and builds a fully compliant AppImage with AppRun, `.desktop` launcher, AppStream metadata, and optional icon support.

---

## Features

- **Interactive prompts** – enter name, version, target binary, and icon.
- **AppStream compliant** – generates valid reverse-DNS IDs, metadata XML, and `.desktop` files.
- **Icon support** – bundle your own PNG icon, or generate a placeholder if ImageMagick is available.
- **Safe packaging** – validates paths, avoids invalid number-starting IDs, and warns on common mistakes.
- **Portable** – works wherever you have `bash` and `appimagetool`.

---

## Requirements

- **Linux system** with `bash`
- `appimagetool` (`appimagetool-x86_64.AppImage` placed in the same folder or installed in `PATH`)
- Optional: [ImageMagick](https://imagemagick.org) (`convert`) for generating placeholder icons

---

## Usage

1. Clone or copy `appImager.sh` into your project folder:
 ```
   git clone https://github.com/74Thirsty/appImager.git
   cd your-repo
   chmod +x appImager.sh
```

2. Run the script:

```
   ./appImager.sh
```

3. Answer the interactive prompts:

   * **App name**: must match your main executable name (letters preferred, avoid starting with numbers).
   * **Target directory**: where the `.AppDir` will be created (defaults to current directory).
   * **Version**: semantic version (e.g. `1.0.0`).
   * **Binary path**: full path to your script or executable.
   * **Icon path**: optional PNG (256×256 recommended).

4. When finished, you’ll see your AppImage in the target directory:

 ```
   ./myApp-x86_64.AppImage
 ```

---

## Example

```
$ ./appImager.sh
==================================================
             INTERACTIVE APPIMAGE BUILDER
==================================================
Enter your app name (must match the executable script name): mytool
Enter target directory path to create AppDir in [/home/user]: 
Enter app version [0.1.0]: 1.2.0
Enter the full path to your executable script or binary: /home/user/dev/mytool.py
Optional: path to a PNG icon (256x256 ideal), or press Enter to skip: /home/user/icons/mytool.png
Enter Reverse-DNS ID base (e.g., io.github.username) — MUST start with a LETTER, not a number [io.github.user]: io.github.myself
```

Output:

```
[appimager] {"level":"INFO","msg":"Packaging AppImage with ./appimagetool-x86_64.AppImage"}
[appimager] {"level":"INFO","msg":"Success"}
Built: /home/user/mytool-x86_64.AppImage
```

---

## Troubleshooting

### ❌ `sysmon{.png,.svg,.xpm} defined in desktop file but not found`

You didn’t provide an icon, and the `.desktop` file expects one.
➡️ Either:

* Provide a **256×256 PNG** icon when prompted, or
* Place `yourApp.png` inside `<AppDir>/yourApp.png` manually.

---

### ❌ `Validation failed: release-time-missing date`

Your AppStream XML is missing release information.
➡️ Add a `<release>` section in `usr/share/metainfo/yourApp.appdata.xml`. Example:

```xml
<releases>
  <release version="1.0.0" date="2025-08-20"/>
</releases>
```

---

### ❌ `cid-desktopapp-is-not-rdns` or `cid-has-number-prefix`

Your AppStream ID or app name is invalid (e.g., starts with a number).
➡️ Always use **reverse-DNS IDs starting with a letter**. Example:

* ✅ `io.github.username.mytool`
* ❌ `74Thirsty.mytool`

---

### ❌ `desktop-file-not-found`

The generated `.desktop` file wasn’t placed correctly.
➡️ Ensure it exists at:

```
<AppDir>/usr/share/applications/yourApp.desktop
```

---

### ❌ `appimagetool: command not found`

The `appimagetool` binary is missing or not executable.
➡️ Download it from [AppImageKit releases](https://github.com/AppImage/AppImageKit/releases) and place it in the script directory:

```bash
chmod +x appimagetool-x86_64.AppImage
```

---

### Third-Party Components
This project bundles `appimagetool-x86_64.AppImage` from [AppImageKit](https://github.com/AppImage/AppImageKit),
licensed under the MIT License. See `LICENSES/AppImageKit-LICENSE.txt` for details.


## Notes

* **Do not use numbers at the start of the app name or reverse-DNS IDs.** AppStream validation will reject these.
* If you provide a Python script as the binary, the launcher automatically runs it with `python3`.
* You can rebuild at any time; existing `.AppDir` folders can be reused or recreated.

---

## License

This script is released under the **MIT License**. Use it freely in your projects.
