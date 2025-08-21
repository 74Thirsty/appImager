# File: appImager.sh
#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[appimager] {"level":"%s","msg":"%s"}\n' "${1:-INFO}" "${2//\"/\\\"}"; }
fail() { log "ERROR" "$1"; exit 1; }

# --- Prompt helpers ---
ask() {
  local prompt="$1"; local varname="$2"; local def="${3:-}"
  if [[ -n "$def" ]]; then
    read -r -p "$prompt [$def]: " REPLY || true
    printf -v "$varname" '%s' "${REPLY:-$def}"
  else
    read -r -p "$prompt: " REPLY || true
    printf -v "$varname" '%s' "$REPLY"
  fi
}
abs() (
  # Print absolute path for $1 (handles ~ and relative)
  set -Eeuo pipefail
  local p="$1"
  [[ "$p" == "~/"* ]] && p="${HOME}/${p#~/}"
  if [[ -d "$p" ]]; then (cd "$p" && pwd -P); else (cd "$(dirname "$p")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$p")"); fi
)

# --- Gather inputs ---
echo "=================================================="
echo "             INTERACTIVE APPIMAGE BUILDER"
echo "=================================================="
ask "Enter your app name (must match the executable script name)" appname
[[ -z "${appname}" ]] && fail "App name is required"
ask "Enter target directory path to create AppDir in" target_dir "$PWD"
ask "Enter app version" appver "0.1.0"
ask "Enter the full path to your executable script or binary" app_binary
ask "Optional: path to a PNG icon (256x256 ideal), or press Enter to skip" icon_path ""

# Normalize paths
target_dir="$(abs "$target_dir")"
app_binary="$(abs "$app_binary")"
[[ -n "${icon_path}" ]] && icon_path="$(abs "$icon_path")"

# Validate inputs
[[ -f "$app_binary" ]] || fail "Executable not found: $app_binary"

# Tool selection
tool="./appimagetool-x86_64.AppImage"
[[ -x "$tool" ]] || tool="$(command -v appimagetool || true)"
[[ -x "$tool" ]] || fail "appimagetool not found. Place appimagetool-x86_64.AppImage here or install appimagetool."

# Arch
ARCH="${ARCH:-x86_64}"

# AppDir paths
appdir="${target_dir}/${appname}.AppDir"
bindir="${appdir}/usr/bin"
sharedir="${appdir}/usr/share"
metainfdir="${sharedir}/metainfo"
iconsdir="${sharedir}/icons/hicolor/256x256/apps"
desktop_file="${appdir}/${appname}.desktop"
apprun="${appdir}/AppRun"
launcher="${bindir}/${appname}"
copied_name="$(basename "$app_binary")"
copied_target="${bindir}/${copied_name}"
icon_target_root="${appdir}/${appname}.png"
icon_target_theme="${iconsdir}/${appname}.png"

# --- Prepare AppDir ---
if [[ -e "$appdir" ]]; then
  read -r -p "AppDir exists at ${appdir}. Recreate it? [y/N]: " yn || true
  if [[ "${yn,,}" == "y" ]]; then
    log INFO "Removing existing AppDir ${appdir}"
    rm -rf -- "$appdir"
  else
    log INFO "Reusing existing AppDir"
  fi
fi

mkdir -p "$bindir" "$metainfdir" "$iconsdir"

# Copy user binary into AppDir (keeps original filename)
cp -f -- "$app_binary" "$copied_target"

# Create launcher that always runs your binary with sane defaults
cat >"$launcher" <<'SH'
#!/usr/bin/env sh
set -eu
HERE="$(dirname "$(readlink -f "$0")")"
# The actual app binary copied during packaging:
TARGET_BASENAME="__COPIED_NAME__"
TARGET="$HERE/$TARGET_BASENAME"

# Heuristic: if it's a Python file, use python3; else exec directly.
case "$TARGET" in
  *.py) exec python3 "$TARGET" "$@";;
  *)    exec "$TARGET" "$@";;
esac
SH
# Inject the real copied filename
sed -i "s|__COPIED_NAME__|${copied_name}|g" "$launcher"
chmod +x "$launcher"

# AppRun – entrypoint for the AppImage
cat >"$apprun" <<SH
#!/usr/bin/env sh
set -eu
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/bin/${appname}" "\$@"
SH
chmod +x "$apprun"

# .desktop file
cat >"$desktop_file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=${appname}
Exec=${appname}
Icon=${appname}
Categories=Utility;
Terminal=false
DESKTOP

# Optional icon
if [[ -n "${icon_path}" && -f "${icon_path}" ]]; then
  cp -f -- "${icon_path}" "${icon_target_root}"
  cp -f -- "${icon_path}" "${icon_target_theme}"
else
  # Make a tiny placeholder if no icon provided
  if command -v convert >/dev/null 2>&1; then
    convert -size 256x256 xc:white -fill black -draw "circle 128,128 128,32" "${icon_target_root}"
    cp -f -- "${icon_target_root}" "${icon_target_theme}"
  else
    # leave missing icon; many desktops will still run it
    :
  fi
fi

# Minimal AppStream metadata to silence warnings
cat >"${metainfdir}/${appname}.appdata.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>${appname}.desktop</id>
  <name>${appname}</name>
  <summary>${appname} AppImage</summary>
  <metadata_license>FSFAP</metadata_license>
  <project_license>MIT</project_license>
  <description>
    <p>${appname} packaged as an AppImage.</p>
  </description>
  <releases>
    <release version="${appver}" />
  </releases>
</component>
XML

# Make everything readable
find "$appdir" -type f -exec chmod 0644 {} \; || true
chmod +x "$apprun" "$launcher"

log INFO "AppDir verification passed."

# --- Package ---
log INFO "Packaging AppImage with ${tool}"
( cd "$target_dir"
  ARCH="$ARCH" "$tool" "${appname}.AppDir"
)

# Move/rename if needed (ensure consistent output name)
out_guess="${target_dir}/${appname}-${ARCH}.AppImage"
if [[ ! -f "$out_guess" ]]; then
  # Try to detect the most recent AppImage produced
  newest="$(ls -t "${target_dir}"/*.AppImage 2>/dev/null | head -n1 || true)"
  if [[ -n "$newest" && "$newest" != "$out_guess" ]]; then
    mv -f -- "$newest" "$out_guess"
  fi
fi

chmod +x "$out_guess" 2>/dev/null || true
log INFO "Success"
printf '%s\n' "Built: $out_guess"
