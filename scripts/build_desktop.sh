#!/usr/bin/env bash
# Build Desktop installers (Electron) for macOS and/or Windows.
# Wraps desktop-app's electron-builder scripts with sensible defaults.
#
# Usage:
#   scripts/build_desktop.sh              # Build for current OS (mac on macOS)
#   scripts/build_desktop.sh --mac        # Build macOS DMG
#   scripts/build_desktop.sh --win        # Build Windows NSIS installer
#   scripts/build_desktop.sh --all        # Attempt both (cross-build toolchain may be required)
#
# Notes:
# - Outputs land in desktop-app/dist/ by default (per electron-builder config).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DESKTOP_DIR="$ROOT_DIR/desktop-app"
PLATFORM="auto"   # auto | mac | win | all

log() { echo -e "\033[1;36m[build_desktop]\033[0m $*"; }
warn() { echo -e "\033[1;33m[build_desktop][warn]\033[0m $*"; }
err() { echo -e "\033[1;31m[build_desktop][error]\033[0m $*" 1>&2; }

usage() {
  cat <<EOF
Build Desktop installers (Electron) for macOS and/or Windows

Options:
  --mac      Build only macOS DMG
  --win      Build only Windows NSIS installer
  --all      Build both macOS and Windows (cross-compile requirements apply)
  -h, --help Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mac) PLATFORM="mac"; shift ;;
    --win) PLATFORM="win"; shift ;;
    --all) PLATFORM="all"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 2 ;;
  esac

done

if [[ ! -d "$DESKTOP_DIR" ]]; then
  err "Desktop app directory not found: $DESKTOP_DIR"; exit 1
fi

pushd "$DESKTOP_DIR" >/dev/null

# Install deps if needed
if [[ ! -d node_modules ]]; then
  log "Installing desktop-app dependencies..."
  npm ci || npm install
fi

# Decide what to build
HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$PLATFORM" == "auto" ]]; then
  if [[ "$HOST_OS" == "darwin" ]]; then
    PLATFORM="mac"
  elif [[ "$HOST_OS" == "mingw" || "$HOST_OS" == msys* || "$HOST_OS" == cygwin* ]]; then
    PLATFORM="win"
  else
    # default to building for host only; linux users can call --all if they have toolchain
    PLATFORM="mac"
  fi
fi

log "Building platform: $PLATFORM"

ensure_win_toolchain_if_needed() {
  # Only check when attempting Windows build from non-Windows hosts (common case: macOS)
  if [[ "$PLATFORM" =~ win|all ]] && [[ "$HOST_OS" == "darwin" || "$HOST_OS" == "linux" ]]; then
    local missing=()
    command -v wine >/dev/null 2>&1 || missing+=("wine")
    command -v makensis >/dev/null 2>&1 || missing+=("nsis")
    # mono is optional for newer setups, but still commonly required; check and note if absent
    command -v mono >/dev/null 2>&1 || missing+=("mono(optional)")
    if [[ ${#missing[@]} -gt 0 ]]; then
      warn "Windows NSIS build may require: ${missing[*]}. If your environment can build without them, you can ignore this."
    fi
  fi
}

case "$PLATFORM" in
  mac)
    npm run build:mac
    ;;
  win)
    ensure_win_toolchain_if_needed
    npm run build:win
    ;;
  all)
    if [[ "$HOST_OS" == "darwin" ]]; then
      npm run build:mac
    fi
    ensure_win_toolchain_if_needed
    npm run build:win
    ;;
  *)
    err "Unknown platform selection: $PLATFORM"; exit 2
    ;;

esac

log "Done. Installers should be in: $DESKTOP_DIR/dist"

popd >/dev/null
