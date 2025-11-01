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
#   scripts/build_apk.sh --release --no-install --out-dir dist --out-name ScriptureDemoPlayer-1.1.0+2-release.apk
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
OUT_DIR=""
OUT_NAME=""

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
  --out-dir <path>       Copy/rename built APK to this directory (created if missing)
  --out-name <name>      Output filename (defaults to a descriptive name if only --out-dir is provided)
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
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --out-name) OUT_NAME="${2:-}"; shift 2 ;;
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

# Determine version info once for naming
APP_VERSION_LINE=$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$APP_DIR/pubspec.yaml" | head -n1 || true)
APP_VERSION_NAME=$(printf "%s" "$APP_VERSION_LINE" | cut -d'+' -f1)
APP_VERSION_CODE=$(printf "%s" "$APP_VERSION_LINE" | cut -s -d'+' -f2)
[[ -z "$APP_VERSION_NAME" ]] && APP_VERSION_NAME="0.0.0"
[[ -z "$APP_VERSION_CODE" ]] && APP_VERSION_CODE="0"

# For release builds, always produce a helpful-named copy in dist unless overridden
if [[ "$MODE" == "release" ]]; then
  DEST_DIR=${OUT_DIR:-"$ROOT_DIR/dist"}
  mkdir -p "$DEST_DIR"
  # Ensure package name is available for naming (be nounset-safe)
  PKG="${PACKAGE_NAME:-}"
  if [[ -z "$PKG" ]]; then
    if [[ -f "$MANIFEST" ]]; then
      PKG=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' "$MANIFEST" | head -n1 || true)
    fi
    [[ -z "$PKG" ]] && PKG="com.example.mobile_app"
  fi
  # Default friendly filename: ScriptureDemoPlayer-<version>
  DEFAULT_NAME="ScriptureDemoPlayer-${APP_VERSION_NAME}+${APP_VERSION_CODE}.apk"
  FINAL_NAME=${OUT_NAME:-"$DEFAULT_NAME"}
  DEST="$DEST_DIR/$FINAL_NAME"
  log "Copying APK to: $DEST"
  cp -f "$APK_PATH" "$DEST"
else
  # Debug builds: only copy/rename if explicitly requested
  if [[ -n "$OUT_DIR" || -n "$OUT_NAME" ]]; then
    DEST_DIR=${OUT_DIR:-"$ROOT_DIR/dist"}
    mkdir -p "$DEST_DIR"
    PKG="${PACKAGE_NAME:-}"
    if [[ -z "$PKG" ]]; then
      if [[ -f "$MANIFEST" ]]; then
        PKG=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' "$MANIFEST" | head -n1 || true)
      fi
      [[ -z "$PKG" ]] && PKG="com.example.mobile_app"
    fi
    SAFE_PKG=${PKG//./-}
    DEFAULT_NAME="${SAFE_PKG}-${APP_VERSION_NAME}+${APP_VERSION_CODE}-${MODE}.apk"
    FINAL_NAME=${OUT_NAME:-"$DEFAULT_NAME"}
    DEST="$DEST_DIR/$FINAL_NAME"
    log "Copying APK to: $DEST"
    cp -f "$APK_PATH" "$DEST"
  fi
fi

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
    # Use sed (portable on macOS/Linux) to extract manifest package attribute
    PACKAGE_NAME=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' "$MANIFEST" | head -n1 || true)
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
if ! adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; then
  warn "Launch via monkey failed. Trying direct 'am start'..."
  # Try to resolve the launcher activity from the device
  RES=$(adb -s "$DEVICE_ID" shell cmd package resolve-activity --brief "$PACKAGE_NAME" 2>/dev/null | tail -n 1 | tr -d '\r' || true)
  if [[ "$RES" != *"/"* ]]; then
    # Try resolving explicitly for MAIN/LAUNCHER
    RES=$(adb -s "$DEVICE_ID" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$PACKAGE_NAME" 2>/dev/null | tail -n 1 | tr -d '\r' || true)
  fi
  if [[ "$RES" != *"/"* ]]; then
    # Fall back to conventional MainActivity path if resolution failed
    RES="$PACKAGE_NAME/.MainActivity"
  fi
  if [[ "$RES" == "No"* || "$RES" == "no"* ]]; then
    err "Unable to resolve launcher activity for $PACKAGE_NAME (got: '$RES')"
    exit 1
  fi
  adb -s "$DEVICE_ID" shell am start -n "$RES"
fi

popd >/dev/null
log "Done."
