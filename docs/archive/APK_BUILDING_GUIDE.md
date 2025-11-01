## APK Build, Install, and Launch Guide

Use the helper script to build a deterministic APK and optionally install/launch it on an emulator or device. This captures the exact flags and steps we standardized during development.

### Quick start

```sh
scripts/build_apk.sh
```

Defaults:
- Debug build
- Gradle configuration cache disabled for reliability
- Installs to the first available adb device
- Launches the app via `adb shell monkey`

### Common usages

```sh
# Pick a device
scripts/build_apk.sh --device emulator-5554

# Release build (no install)
scripts/build_apk.sh --release --no-install

# Skip analyzer or launch
scripts/build_apk.sh --no-analyze
scripts/build_apk.sh --no-launch

# Uninstall first (clean reinstall)
scripts/build_apk.sh --uninstall-first

# Override package (if auto-detect fails)
scripts/build_apk.sh --package com.example.mobile_app
```

### What the script does

1. Runs `flutter analyze` (can be skipped with `--no-analyze`).
2. Builds the APK with Gradle config cache disabled:
	- Debug: `flutter build apk --debug`
	- Release: `flutter build apk --release`
3. Installs the built APK to the selected device (`adb install -r`).
4. Launches the app using `adb shell monkey` (no need to know the main activity).

APK output paths the script expects:
- Debug: `mobile_app/build/app/outputs/flutter-apk/app-debug.apk`
- Release: `mobile_app/build/app/outputs/flutter-apk/app-release.apk`

### Requirements

- Flutter SDK in PATH (`flutter`)
- Android platform-tools in PATH (`adb`)
- A running emulator or connected device (`adb devices`)

If multiple devices are connected, pass `--device <id>` to choose.

### Notes

- The Android package name is auto-detected from `mobile_app/android/app/src/main/AndroidManifest.xml`. Use `--package` to override if needed.
- The script is idempotent and safe to rerun; use `--uninstall-first` for a clean reinstall.
