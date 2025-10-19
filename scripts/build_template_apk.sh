#!/usr/bin/env bash
set -euo pipefail

# Build a React Native 0.72 template APK compatible with this repo
# Usage: ./scripts/build_template_apk.sh
# Requires: Node 16+, JDK 11+, Android SDK, RN CLI (@react-native-community/cli)

# --- Config ---
RN_VERSION="0.72.17"
APP_NAME="ScriptureTemplate"
PACKAGE_NAME="com.scripturemedia.template"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.template-build"
OUTPUT_APK="$ROOT_DIR/apk-template/template.apk"

# Try to ensure we're using JDK 17 (required by modern AGP and avoids class file version issues)
if [[ "$(uname)" == "Darwin" ]]; then
  if /usr/libexec/java_home -V >/dev/null 2>&1; then
    if JAVA17_PATH=$(/usr/libexec/java_home -v 17 2>/dev/null); then
      export JAVA_HOME="$JAVA17_PATH"
      export PATH="$JAVA_HOME/bin:$PATH"
    fi
  fi
fi

echo "JAVA_HOME=${JAVA_HOME:-not set}"
java -version || true

mkdir -p "$WORK_DIR"

echo "[1/6] Creating RN $RN_VERSION project in $WORK_DIR/$APP_NAME ..."
cd "$WORK_DIR"
rm -rf "$APP_NAME"
npx react-native init "$APP_NAME" --version $RN_VERSION --skip-install
cd "$APP_NAME"

echo "[2/6] Installing dependencies ..."
npm install
# Match repo dependencies and install local shared package
npm install \
  @react-native-async-storage/async-storage \
  react-native-device-info \
  react-native-fs \
  react-native-video

# Install local shared package to satisfy imports like '@scripture-media/shared'
npm install "@scripture-media/shared@file:$ROOT_DIR/shared"

# Link shared JS from repo into the template app (copy minimal files)
echo "[3/6] Copying JS from repo mobile-app ..."
SRC_DIR="$ROOT_DIR/mobile-app"
# Replace App.js and JS configs
cp -f "$SRC_DIR/App.js" ./App.js || true
cp -f "$SRC_DIR/index.js" ./index.js || true
cp -f "$SRC_DIR/babel.config.js" ./babel.config.js || true
cp -f "$SRC_DIR/metro.config.js" ./metro.config.js || true
# Copy src directory
rm -rf ./src
cp -R "$SRC_DIR/src" ./src

# Ensure package name if needed (optional sed edits)
# You can adjust Android package later; default is fine for template APK.

echo "[4/6] Building release APK ..."
cd android
# Ensure Gradle uses our JAVA_HOME if set
if [[ -n "${JAVA_HOME:-}" ]]; then
  echo "org.gradle.java.home=$JAVA_HOME" >> gradle.properties
fi
./gradlew clean
./gradlew assembleRelease

APK_PATH="app/build/outputs/apk/release/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "ERROR: APK not found at $APK_PATH" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/apk-template"
cp -f "$APK_PATH" "$OUTPUT_APK"

echo "[5/6] Verifying output ..."
ls -lh "$OUTPUT_APK"

echo "[6/6] Done. Template APK copied to: $OUTPUT_APK"
echo "You can now use the Desktop Bundler to package bundles (no compile)."