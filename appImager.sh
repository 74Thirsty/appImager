#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo "        AppImage Builder - Interactive        "
echo "=============================================="

# --- Ask for script path ---
while true; do
    read -rp "Enter the full path to your script (.py or .sh): " SCRIPT_FILE
    if [ -f "$SCRIPT_FILE" ]; then
        break
    else
        echo "[!] File not found. Please enter a valid path."
    fi
done

# --- Ask for application name ---
read -rp "Enter application name (no spaces recommended): " APP_NAME
APP_NAME="${APP_NAME:-MyApp}"

# --- Ask for icon ---
read -rp "Enter path to icon (.png, optional - press Enter to skip): " ICON_FILE
if [ -n "$ICON_FILE" ] && [ ! -f "$ICON_FILE" ]; then
    echo "[!] Icon file not found. Skipping."
    ICON_FILE=""
fi

# --- Ask terminal preference ---
read -rp "Should the app run in a terminal? (y/N): " TERM_ANS
if [[ "$TERM_ANS" =~ ^[Yy]$ ]]; then
    USE_TERMINAL="true"
else
    USE_TERMINAL="false"
fi

# --- Prepare build directory ---
APPDIR="${APP_NAME}.AppDir"
echo "[*] Setting up build directory: $APPDIR"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Copy main script
cp "$SCRIPT_FILE" "$APPDIR/"

# Optional icon
if [ -n "$ICON_FILE" ]; then
    cp "$ICON_FILE" "${APPDIR}/${APP_NAME}.png"
    ICON_NAME="$APP_NAME"
else
    ICON_NAME="utilities-terminal"
fi

# --- Detect script type ---
EXT="${SCRIPT_FILE##*.}"
if [[ "$EXT" == "py" ]]; then
    echo "[*] Detected Python script"
    cat > "$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec python3 "\$HERE/$(basename "$SCRIPT_FILE")" "\$@"
EOF
elif [[ "$EXT" == "sh" ]]; then
    echo "[*] Detected Bash script"
    chmod +x "$APPDIR/$(basename "$SCRIPT_FILE")"
    cat > "$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/$(basename "$SCRIPT_FILE")" "\$@"
EOF
else
    echo "[!] Unsupported script type: .$EXT"
    exit 1
fi
chmod +x "$APPDIR/AppRun"

# --- Desktop entry ---
cat > "$APPDIR/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Exec=AppRun
Icon=$ICON_NAME
Terminal=$USE_TERMINAL
Categories=Utility;
EOF

# --- Download appimagetool if missing ---
if [ ! -f appimagetool-x86_64.AppImage ]; then
    echo "[*] Downloading appimagetool..."
    DOWNLOAD_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

if command -v wget >/dev/null 2>&1; then
    wget -O appimagetool-x86_64.AppImage "$DOWNLOAD_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o appimagetool-x86_64.AppImage "$DOWNLOAD_URL"
else
    echo "[!] Neither wget nor curl found. Please install one and re-run."
    exit 1
fi
chmod +x appimagetool-x86_64.AppImage

if [ ! -x appimagetool-x86_64.AppImage ]; then
    echo "[!] Download failed or file not executable. Aborting."
    exit 1
fi

    if command -v wget >/dev/null 2>&1; then
        wget -O appimagetool-x86_64.AppImage "$URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o appimagetool-x86_64.AppImage "$URL"
    else
        echo "[!] Neither wget nor curl found. Please install one and re-run."
        exit 1
    fi
    chmod +x appimagetool-x86_64.AppImage
fi

# --- Verify appimagetool works ---
if [ ! -x appimagetool-x86_64.AppImage ]; then
    echo "[!] appimagetool download failed or is not executable."
    exit 1
fi

# --- Confirm before building ---
echo "=============================================="
echo "Script:        $SCRIPT_FILE"
echo "App Name:      $APP_NAME"
echo "Icon:          ${ICON_FILE:-[default]}"
echo "Terminal:      $USE_TERMINAL"
echo "Output:        ${APP_NAME}-x86_64.AppImage"
echo "=============================================="
read -rp "Proceed with build? (Y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
    echo "Aborted."
    exit 0
fi

# --- Build ---
echo "[*] Building AppImage..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR"

# --- Cleanup build dir ---
rm -rf "$APPDIR"

# --- Done ---
echo "[✓] Build complete: ${APP_NAME}-x86_64.AppImage"
echo "    Double-click to run or execute: ./\"${APP_NAME}-x86_64.AppImage\""
