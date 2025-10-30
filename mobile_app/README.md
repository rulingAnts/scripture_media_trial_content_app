# Scripture Media — Mobile App

Flutter app to import a Scripture Media bundle (.smbundle), decrypt media for the authorized device, and play it offline.

## Quick test on Android

Prerequisites:

- Flutter SDK installed and on PATH
- Android SDK/NDK via Android Studio
- A device (USB) with Developer options and USB debugging enabled, or an emulator

1) Verify toolchain and device

```bash
flutter doctor
flutter devices
```

2) Run the app on a device/emulator

```bash
cd mobile_app
flutter run
```

This launches the app and streams the build to the selected device. If multiple devices exist, add `-d <deviceId>`.

3) Alternatively, build and install a debug APK

We provide a VS Code task that disables Gradle’s configuration cache (required on some setups). From VS Code: Run Task → “Flutter: Build debug APK (cache-off)”. Or run manually:

```bash
cd mobile_app
env GRADLE_OPTS='-Dorg.gradle.configuration-cache=false -Dorg.gradle.unsafe.configuration-cache=false' flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

4) Import your bundle in the app

- Open the app on the device
- Tap the “Import Bundle” FAB
- Select the `.smbundle` file
- The app will extract, attempt to decrypt config (best-effort), decrypt media for the device, and play the first media file

Notes:

- The desktop bundler encrypts media for the first device ID provided. Decryption will only work on that device.
- The app stores the last played path and config, so on relaunch it resumes playback if present.

## iOS

Not configured yet for distribution. You can still run on simulator with `flutter run -d ios` after setting up code signing if needed.

## Troubleshooting

- If Android build fails with a "configuration cache" error, use the provided VS Code task or the `GRADLE_OPTS` environment variables shown above.
- Ensure your `.smbundle` was produced by the included desktop app and includes `media/*.enc` files.
