# File: appImager.sh
#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[appimager] {"level":"%s","msg":"%s"}\n' "${1:-INFO}" "${2//\"/\\\"}"; }
fail() { log "ERROR" "$1"; exit 1; }

# Use the directory you EXECUTE this script from (stable across cd's)
INVOKED_DIR="$(pwd -P)"

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

# Ask for RDNS base and block number-starting IDs (AppStream requirement)
default_rdns="io.github.${USER:-user}"
while :; do
  ask "Enter Reverse-DNS ID base (e.g., io.github.username) — MUST start with a LETTER, not a number" rdns_base "$default_rdns"
  rdns_base="${rdns_base,,}"  # lowercase
  if [[ "$rdns_base" =~ ^[a-z][a-z0-9._-]*$ ]]; then
    break
  fi
  echo ">>> Invalid RDNS base. It must start with a LETTER and contain only [a-z0-9._-]. Do NOT start with a number."
done

# Normalize paths
target_dir="$(abs "$target_dir")"
app_binary="$(abs "$app_binary")"
[[ -n "${icon_path}" ]] && icon_path="$(abs "$icon_path")"

# Validate inputs
[[ -f "$app_binary" ]] || fail "Executable not found: $app_binary"

# --- Tool selection (prefer tool in the directory you EXECUTED from; then PATH) ---
local_tool="${INVOKED_DIR}/appimagetool-x86_64.AppImage"
if [[ -x "$local_tool" ]]; then
  tool="$(readlink -f "$local_tool")"
  log INFO "Using local appimagetool from invoke dir: $tool"
elif command -v appimagetool >/dev/null 2>&1; then
  tool="$(command -v appimagetool)"
  log INFO "Using system appimagetool in PATH: $tool"
else
  fail "appimagetool not found in invoke dir (${INVOKED_DIR}) or PATH. Place appimagetool-x86_64.AppImage where you run this, or install appimagetool."
fi

# Arch
ARCH="${ARCH:-x86_64}"

# Compute safe component id for AppStream (avoid number-starting segment)
app_id_part="${appname,,}"
if [[ "$app_id_part" =~ ^[0-9] ]]; then
  log "WARN" "App name '${appname}' begins with a number; AppStream IDs can't have segments starting with numbers. Prefixing '_' for metadata ID."
  app_id_part="_${app_id_part}"
fi
component_id="${rdns_base}.${app_id_part}"

# AppDir paths
appdir="${target_dir}/${appname}.AppDir"
bindir="${appdir}/usr/bin"
sharedir="${appdir}/usr/share"
metainfdir="${sharedir}/metainfo"
appsdir="${sharedir}/applications"
iconsdir="${sharedir}/icons/hicolor/256x256/apps"

desktop_file_root="${appdir}/${appname}.desktop"
desktop_file_sys="${appsdir}/${appname}.desktop"
apprun="${appdir}/AppRun"
launcher="${bindir}/${appname}"
copied_name="$(basename "$app_binary")"
copied_target="${bindir}/${copied_name}"
icon_target_root="${appdir}/${appname}.png"
icon_target_theme="${iconsdir}/${appname}.png"
metainfo_file="${metainfdir}/${component_id}.appdata.xml"

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

mkdir -p "$bindir" "$metainfdir" "$iconsdir" "$appsdir"

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

# Decide whether to include Icon= in the .desktop
ICON_LINE=""
if [[ -n "${icon_path}" && -f "${icon_path}" ]]; then
  cp -f -- "${icon_path}" "${icon_target_root}"
  cp -f -- "${icon_path}" "${icon_target_theme}"
  ICON_LINE="Icon=${appname}"
else
  # Try to make a placeholder if ImageMagick is available
  if command -v convert >/dev/null 2>&1; then
    convert -size 256x256 xc:white -fill black -gravity center \
      -pointsize 64 -annotate 0 "${appname:0:1}" "${icon_target_root}"
    cp -f -- "${icon_target_root}" "${icon_target_theme}"
    ICON_LINE="Icon=${appname}"
  else
    log "WARN" "No icon provided and 'convert' not found; building without Icon= to avoid validation errors."
  fi
fi

# .desktop file (place in usr/share/applications and copy to AppDir root)
cat >"$desktop_file_sys" <<DESKTOP
[Desktop Entry]
Type=Application
Name=${appname}
Exec=${appname}
${ICON_LINE}
Categories=Utility;
Terminal=false
DESKTOP
cp -f -- "$desktop_file_sys" "$desktop_file_root"

# AppStream metadata (RDNS id + launchable + release date + description)
cat >"$metainfo_file" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>${component_id}</id>
  <launchable type="desktop-id">${appname}.desktop</launchable>
  <name>${appname}</name>
  <summary>${appname} AppImage</summary>
  <metadata_license>FSFAP</metadata_license>
  <project_license>MIT</project_license>
  <description>
    <p>${appname} is packaged as a portable AppImage. It bundles your entrypoint script or binary
    and runs on most modern Linux distributions without installation. This build injects your
    specified executable into <code>usr/bin</code> and wires AppRun to execute it via a lightweight launcher.</p>
  </description>
  <releases>
    <release version="${appver}" date="$(date +%Y-%m-%d)" />
  </releases>
</component>
XML

# Relax perms on files, then re-mark executables
find "$appdir" -type f -exec chmod 0644 {} \; || true
chmod +x "$apprun" "$launcher"
# If the copied target isn't a .py, ensure it's executable (launcher will exec it directly)
case "$copied_target" in
  *.py) : ;;
  *) chmod +x "$copied_target" || true ;;
esac

log INFO "AppDir verification passed."

# --- Package ---
log INFO "Packaging AppImage with ${tool}"
(
  cd "$target_dir"
  ARCH="${ARCH:-x86_64}" "$tool" "${appname}.AppDir"
)

# Move/rename if needed (ensure consistent output name)
out_guess="${target_dir}/${appname}-${ARCH}.AppImage"
if [[ ! -f "$out_guess" ]]; then
  newest="$(ls -t "${target_dir}"/*.AppImage 2>/dev/null | head -n1 || true)"
  if [[ -n "$newest" && "$newest" != "$out_guess" ]]; then
    mv -f -- "$newest" "$out_guess"
  fi
fi

chmod +x "$out_guess" 2>/dev/null || true
log INFO "Success"
printf '%s\n' "Built: $out_guess"
