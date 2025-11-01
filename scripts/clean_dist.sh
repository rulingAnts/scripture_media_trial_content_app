#!/usr/bin/env bash
# Clean old build artifacts from dist folders, keeping only current release outputs.
# - Keeps current desktop version (DMG/EXE) under desktop-app/dist
# - Keeps current APK under dist (ScriptureDemoPlayer-<version>.apk)
# - Removes .blockmap, builder debug/effective configs, and unpacked folders

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DESKTOP_DIR="$ROOT_DIR/desktop-app"
DESKTOP_DIST="$DESKTOP_DIR/dist"
ROOT_DIST="$ROOT_DIR/dist"

info() { echo -e "\033[1;36m[clean_dist]\033[0m $*"; }
warn() { echo -e "\033[1;33m[clean_dist][warn]\033[0m $*"; }
err()  { echo -e "\033[1;31m[clean_dist][error]\033[0m $*" 1>&2; }

# Get current desktop version from package.json (very basic parsing)
DESKTOP_VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$DESKTOP_DIR/package.json" | head -n1 || true)
if [[ -z "$DESKTOP_VER" ]]; then
  warn "Could not parse desktop version from desktop-app/package.json; will not prune by version."
fi

# Get current app version from pubspec.yaml (versionName+versionCode)
APP_VER_LINE=$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$ROOT_DIR/mobile_app/pubspec.yaml" | head -n1 || true)
if [[ -z "$APP_VER_LINE" ]]; then
  warn "Could not parse app version from mobile_app/pubspec.yaml; APK pruning may be skipped."
fi

info "Desktop version: ${DESKTOP_VER:-unknown}"
info "App version: ${APP_VER_LINE:-unknown}"

# Clean desktop dist
if [[ -d "$DESKTOP_DIST" ]]; then
  info "Cleaning desktop dist: $DESKTOP_DIST"
  pushd "$DESKTOP_DIST" >/dev/null

  # Always remove ephemeral files
  rm -f builder-debug.yml builder-effective-config.yaml || true
  rm -f .DS_Store || true
  rm -f *.blockmap || true

  # Remove unpacked build folders
  rm -rf mac-* win-*-unpacked linux-* || true

  if [[ -n "${DESKTOP_VER:-}" ]]; then
    # Remove any DMG/EXE that do not contain the current version
    for f in *.dmg *.exe; do
      [[ -e "$f" ]] || continue
      if [[ "$f" != *"-$DESKTOP_VER"* && "$f" != *" $DESKTOP_VER"* ]]; then
        info "Deleting old desktop artifact: $f"
        rm -f -- "$f" || true
      fi
    done
  fi

  popd >/dev/null
else
  info "No desktop dist directory present: $DESKTOP_DIST"
fi

# Clean root dist (APK copies)
if [[ -d "$ROOT_DIST" ]]; then
  info "Cleaning root dist: $ROOT_DIST"
  pushd "$ROOT_DIST" >/dev/null

  # Keep only ScriptureDemoPlayer-<version>.apk
  if [[ -n "${APP_VER_LINE:-}" ]]; then
    KEEP="ScriptureDemoPlayer-${APP_VER_LINE}.apk"
    for f in *.apk; do
      [[ -e "$f" ]] || continue
      if [[ "$f" != "$KEEP" ]]; then
        info "Deleting old APK: $f"
        rm -f -- "$f" || true
      fi
    done
  else
    warn "App version unknown; skipping APK pruning."
  fi

  popd >/dev/null
else
  info "No root dist directory present: $ROOT_DIST"
fi

info "Cleanup complete."
