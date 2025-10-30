#!/usr/bin/env bash
# Deterministic Flutter APK build + optional install/launch helper
#
# Usage examples:
#   scripts/build_apk.sh                    # Debug build, install to first device, and launch
#   scripts/build_apk.sh --device emulator-5554
#   scripts/build_apk.sh --release --no-install
#   scripts/build_apk.sh --package com.example.mobile_app
#   scripts/build_apk.sh --no-launch
#   scripts/build_apk.sh --uninstall-first
#
# Notes:
# - Disables Gradle configuration cache for stability (as used during development).
# - Falls back to launching via `adb shell monkey` so we don't need to know the main activity.
# - Attempts to auto-detect the Android package from AndroidManifest.xml; can be overridden via --package.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
APP_DIR="$ROOT_DIR/mobile_app"
MANIFEST="$APP_DIR/android/app/src/main/AndroidManifest.xml"
MODE="debug"
DO_INSTALL=1
DO_LAUNCH=1
DO_ANALYZE=1
UNINSTALL_FIRST=0
DEVICE_ID=""
PACKAGE_OVERRIDE=""

log() { echo -e "\033[1;36m[build_apk]\033[0m $*"; }
warn() { echo -e "\033[1;33m[build_apk][warn]\033[0m $*"; }
err() { echo -e "\033[1;31m[build_apk][error]\033[0m $*" 1>&2; }

usage() {
  cat <<EOF
Deterministic Flutter APK build + optional install/launch helper

Options:
  --debug                Build debug APK (default)
  --release              Build release APK
  --device <id>          adb device/emulator id (from `adb devices`)
  --no-install           Do not install APK after build
  --no-launch            Do not launch app after install
  --uninstall-first      Uninstall the app before installing (keeps data only if Android allows)
  --no-analyze           Skip 'flutter analyze'
  --package <name>       Override Android package name (otherwise auto-detected)
  -h, --help             Show this help

Examples:
  scripts/build_apk.sh --device emulator-5554
  scripts/build_apk.sh --release --no-install
  scripts/build_apk.sh --package com.example.mobile_app
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) MODE="debug"; shift ;;
    --release) MODE="release"; shift ;;
    --device) DEVICE_ID="${2:-}"; shift 2 ;;
    --no-install) DO_INSTALL=0; shift ;;
    --no-launch) DO_LAUNCH=0; shift ;;
    --uninstall-first) UNINSTALL_FIRST=1; shift ;;
    --no-analyze) DO_ANALYZE=0; shift ;;
    --package) PACKAGE_OVERRIDE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 2 ;;
  esac
done

# Prechecks
command -v flutter >/dev/null 2>&1 || { err "flutter not found in PATH"; exit 1; }
command -v adb >/dev/null 2>&1 || { err "adb not found in PATH (install Android platform-tools)"; exit 1; }

if [[ ! -d "$APP_DIR" ]]; then
  err "Flutter app dir not found: $APP_DIR"; exit 1
fi

pushd "$APP_DIR" >/dev/null

if [[ $DO_ANALYZE -eq 1 ]]; then
  log "Running flutter analyze..."
  flutter analyze || { err "Analyzer reported issues (continuing anyway)"; }
fi

log "Building $MODE APK with Gradle config cache disabled..."
# Keep exactly the Gradle flags we used during development for stable builds
if [[ "$MODE" == "debug" ]]; then
  GRADLE_OPTS='-Dorg.gradle.configuration-cache=false -Dorg.gradle.unsafe.configuration-cache=false' \
    flutter build apk --debug
  APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
else
  GRADLE_OPTS='-Dorg.gradle.configuration-cache=false -Dorg.gradle.unsafe.configuration-cache=false' \
    flutter build apk --release
  APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
fi

if [[ ! -f "$APK_PATH" ]]; then
  err "APK not found at $APK_PATH"; exit 1
fi
log "Built: $APK_PATH"

if [[ $DO_INSTALL -eq 0 ]]; then
  log "Skipping install as requested"
  popd >/dev/null
  exit 0
fi

# Choose device
if [[ -z "$DEVICE_ID" ]]; then
  DEVICES=($(adb devices | awk '$2=="device" {print $1}'))
  if [[ ${#DEVICES[@]} -eq 0 ]]; then
    err "No adb devices found. Start an emulator or connect a device."; exit 1
  fi
  if [[ ${#DEVICES[@]} -gt 1 ]]; then
    warn "Multiple devices found; defaulting to: ${DEVICES[0]} (override with --device)"
  fi
  DEVICE_ID=${DEVICES[0]}
fi
log "Using device: $DEVICE_ID"

# Determine package name
PACKAGE_NAME="$PACKAGE_OVERRIDE"
if [[ -z "$PACKAGE_NAME" ]]; then
  if [[ -f "$MANIFEST" ]]; then
    PACKAGE_NAME=$(grep -Po 'package="\K[^"]+' "$MANIFEST" | head -n1 || true)
  fi
  if [[ -z "$PACKAGE_NAME" ]]; then
    warn "Could not auto-detect package from AndroidManifest.xml; defaulting to com.example.mobile_app"
    PACKAGE_NAME="com.example.mobile_app"
  fi
fi
log "Android package: $PACKAGE_NAME"

# Optionally uninstall first
if [[ $UNINSTALL_FIRST -eq 1 ]]; then
  log "Uninstalling existing app (if present)..."
  adb -s "$DEVICE_ID" uninstall "$PACKAGE_NAME" >/dev/null 2>&1 || true
fi

# Install APK
log "Installing APK..."
adb -s "$DEVICE_ID" install -r "$APK_PATH"

if [[ $DO_LAUNCH -eq 0 ]]; then
  log "Install complete. Skipping launch as requested."
  popd >/dev/null
  exit 0
fi

# Launch app via monkey (doesn't require knowing the main activity)
log "Launching app ($PACKAGE_NAME)..."
adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || {
  warn "Launch via monkey failed. Trying direct 'am start'..."
  adb -s "$DEVICE_ID" shell cmd package resolve-activity --brief "$PACKAGE_NAME" | tail -n 1 | xargs -I {} adb -s "$DEVICE_ID" shell am start -n {}
}

popd >/dev/null
log "Done."
