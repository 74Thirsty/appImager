# **appImager**

![GADGET SAAVY banner](https://raw.githubusercontent.com/74Thirsty/74Thirsty/main/assets/banner.svg)

## 🔧 Technologies & Tools

[![Cyfrin](https://img.shields.io/badge/Cyfrin-Audit%20Ready-005030?logo=shield&labelColor=F47321)](https://www.cyfrin.io/)
[![FlashBots](https://img.shields.io/pypi/v/finta?label=Finta&logo=python&logoColor=2774AE&labelColor=FFD100)](https://www.flashbots.net/)
[![Python](https://img.shields.io/badge/Python-3.11-003057?logo=python&labelColor=B3A369)](https://www.python.org/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-7BAFD4?logo=ethereum&labelColor=4B9CD3)](https://docs.soliditylang.org)
[![pYcHARM](https://img.shields.io/badge/Built%20with-PyCharm-782F40?logo=pycharm&logoColor=CEB888)](https://www.jetbrains.com/pycharm/)
[![Issues](https://img.shields.io/github/issues/74Thirsty/appImager.svg?color=hotpink&labelColor=brightgreen)](https://github.com/74Thirsty/appImager/issues)
[![Lead Dev](https://img.shields.io/badge/C.Hirschauer-Lead%20Developer-041E42?logo=parrotsecurity&labelColor=C5B783)](https://christopherhirschauer.bio)
[![Security](https://img.shields.io/badge/encryption-AES--256-orange.svg?color=13B5EA&labelColor=9EA2A2)]()

> <p><strong>Christopher Hirschauer</strong><br>
> Builder @ the bleeding edge of MEV, automation, and high-speed arbitrage.<br>
<em>June 13, 2025</em></p>



* Runs on most modern Linux distros without installation.
* Keeps your app as a single file — easy to send or host.
* Double-clickable in most file managers.
* No root needed.
* Can bundle your dependencies so users don’t need to install anything.

---

## **1. Prepare Your Script**

Make sure your script works when run normally.

Example **Bash** script:

```bash
#!/usr/bin/env bash
echo "Hello from my AppImage!"
read -p "Press Enter to exit..."
```

Example **Python** script:

```python
#!/usr/bin/env python3
print("Hello from my Python AppImage!")
input("Press Enter to exit...")
```

Give it execute permission:

```bash
chmod +x myscript.sh  # or myscript.py
```

Test it:

```bash
./myscript.sh
```

---

## **2. Directory Structure for AppImage**

AppImages require an `AppDir` with a specific layout:

```
MyApp.AppDir/
 ├── AppRun
 ├── myscript.sh   (your script/binary)
 ├── myicon.png    (optional icon)
 └── myapp.desktop
```

---

## **3. Create the AppRun File**

`AppRun` is the entry point. It runs when the AppImage starts.

Example for Bash script:

```bash
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/myscript.sh" "$@"
```

Example for Python script:

```bash
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
exec python3 "$HERE/myscript.py" "$@"
```

Make it executable:

```bash
chmod +x MyApp.AppDir/AppRun
```

---

## **4. Create the .desktop File**

This makes it appear in menus and supports icons.

`MyApp.AppDir/myapp.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=My App
Exec=AppRun
Icon=myicon
Terminal=true
Categories=Utility;
```

* `Exec=AppRun` — tells AppImage to run your AppRun file.
* `Icon=myicon` — matches `myicon.png` in the AppDir (no extension in `.desktop`).
* `Terminal=true` if you want a terminal window, false for GUI.

---

## **5. Add an Icon**

Place a 256×256 PNG file named `myicon.png` in `MyApp.AppDir/`.

---

## **6. Bundle Dependencies (Optional)**

If your script needs extra binaries/libraries, copy them inside `MyApp.AppDir/usr/bin` and `MyApp.AppDir/usr/lib`.

For Python:

* Use `pip install --target MyApp.AppDir/usr/lib/python3.X/site-packages <package>` to bundle packages.
* Or freeze it into a binary with **PyInstaller/Nuitka** first, then just drop the binary in place of the script.

---

## **7. Get `appimagetool`**

Download the official AppImage builder:

```bash
wget https://github.com/AppImage/AppImageKit/releases/latest/download/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
```

---

## **8. Build the AppImage**

Run:

```bash
./appimagetool-x86_64.AppImage MyApp.AppDir
```

It outputs:

```
MyApp-x86_64.AppImage
```

---

## **9. Test the AppImage**

```bash
chmod +x MyApp-x86_64.AppImage
./MyApp-x86_64.AppImage
```

Or double-click it in your file manager.

---

## **10. (Optional) Obfuscate the Source**

If you want to **hide the source** before packaging:

* **Python:** Compile with Nuitka or PyInstaller first, replace script with binary.
* **Bash:** Use `shc` to compile it.
* **Node:** Use `pkg` to make an executable.

Drop the compiled binary into `MyApp.AppDir/` instead of the plain script.

---

## **Example: Python Script to AppImage**

```bash
mkdir -p MyApp.AppDir
cp myscript.py MyApp.AppDir/
cp myicon.png MyApp.AppDir/

# AppRun
cat > MyApp.AppDir/AppRun <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
exec python3 "$HERE/myscript.py" "$@"
EOF
chmod +x MyApp.AppDir/AppRun

# Desktop file
cat > MyApp.AppDir/myapp.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=My Python App
Exec=AppRun
Icon=myicon
Terminal=true
Categories=Utility;
EOF

# Build
wget https://github.com/AppImage/AppImageKit/releases/latest/download/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
./appimagetool-x86_64.AppImage MyApp.AppDir
```

Now you have:

```
MyApp-x86_64.AppImage
```

✅ Runs anywhere, double-clickable, doesn’t need install.

Here is a ready made appimage build script!
```
#!/usr/bin/env bash
# ============================================================================
# make_appimage.sh
# Turn any Python or Bash script into a double-clickable AppImage
# Usage: ./make_appimage.sh myscript.py "My App Name" myicon.png
# ============================================================================
set -euo pipefail

# --- Check args ---
if [ $# -lt 2 ]; then
    echo "Usage: $0 <script_file> <AppName> [icon.png]"
    exit 1
fi

SCRIPT_FILE="$1"
APP_NAME="$2"
ICON_FILE="${3:-}"

# --- Paths ---
APPDIR="${APP_NAME}.AppDir"
APP_RUN="${APPDIR}/AppRun"
DESKTOP_FILE="${APPDIR}/${APP_NAME}.desktop"

# --- Prepare AppDir ---
echo "[*] Preparing AppDir..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Copy script
cp "$SCRIPT_FILE" "$APPDIR/"

# Optional icon
if [ -n "$ICON_FILE" ] && [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "${APPDIR}/${APP_NAME}.png"
    ICON_NAME="$APP_NAME"
else
    ICON_NAME="utilities-terminal"
fi

# --- Detect script type ---
EXT="${SCRIPT_FILE##*.}"
if [[ "$EXT" == "py" ]]; then
    echo "[*] Detected Python script"
    cat > "$APP_RUN" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec python3 "\$HERE/$(basename "$SCRIPT_FILE")" "\$@"
EOF
elif [[ "$EXT" == "sh" ]]; then
    echo "[*] Detected Bash script"
    chmod +x "$APPDIR/$(basename "$SCRIPT_FILE")"
    cat > "$APP_RUN" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/$(basename "$SCRIPT_FILE")" "\$@"
EOF
else
    echo "[!] Unsupported file extension: $EXT"
    exit 1
fi
chmod +x "$APP_RUN"

# --- Desktop file ---
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Exec=AppRun
Icon=$ICON_NAME
Terminal=true
Categories=Utility;
EOF

# --- Get appimagetool ---
if [ ! -f appimagetool-x86_64.AppImage ]; then
    echo "[*] Downloading appimagetool..."
    wget -q https://github.com/AppImage/AppImageKit/releases/latest/download/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

# --- Build ---
echo "[*] Building AppImage..."
./appimagetool-x86_64.AppImage "$APPDIR"

# --- Output ---
echo "[✓] AppImage built: ${APP_NAME}-x86_64.AppImage"
echo "    Double-click to run, or execute: ./\"${APP_NAME}-x86_64.AppImage\""
```

## **How to Use**

```bash
chmod +x make_appimage.sh

# For Python script:
./make_appimage.sh myscript.py "My Python App" myicon.png

# For Bash script:
./make_appimage.sh myscript.sh "My Bash App" myicon.png
```

Output:

```
My Python App-x86_64.AppImage
```

✅ Double-click it or run in terminal.

---

## **Extra Features in This Script**

* Auto-detects `.py` or `.sh`.
* Optional icon support (if not provided, defaults to system terminal icon).
* Downloads `appimagetool` if missing.
* Cleans previous build folder automatically.
* Works entirely offline after first run.
* Single file — easy to carry around.
