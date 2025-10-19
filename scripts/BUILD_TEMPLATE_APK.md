# Build the Template APK (One-time by Maintainers)

This repository’s desktop app supports a no-compile packing path by injecting bundles into a prebuilt Template APK. You (a maintainer) need to produce this Template APK once, then content creators can package APKs without any Android tooling.

## Requirements (maintainer machine only)

- macOS or Linux recommended
- Node.js 16+
- Android Studio + Android SDK Platform 33+
- Java JDK 11+
- React Native CLI

```bash
npm install -g @react-native-community/cli
```

## Steps

1. Initialize Android Native Project for `mobile-app`

If the `mobile-app/android` folder does not exist, create a bare React Native Android project that matches the versions in `mobile-app/package.json` (React Native ^0.72.x) and integrate:

- `@react-native-async-storage/async-storage`
- `react-native-device-info`
- `react-native-fs`
- `react-native-video`
- Link/auto-link these native modules (RN autolinking should handle this on 0.72).

Alternatively, start from a fresh RN 0.72 template app, copy over our `mobile-app/src` and JS configuration (App.js, index.js, metro.config.js, babel.config.js), then ensure it builds.

2. Configure Android signing (optional for release)

If building a release APK:
- Create a keystore (or reuse existing)
- Configure `android/app/build.gradle` signingConfigs and `release` buildType

3. Build Release APK

```bash
cd mobile-app/android
./gradlew clean
./gradlew assembleRelease
```

Output:

```
mobile-app/android/app/build/outputs/apk/release/app-release.apk
```

4. Save as Template

Copy the output APK to the repo’s template folder:

```bash
cp mobile-app/android/app/build/outputs/apk/release/app-release.apk apk-template/template.apk
```

Do not commit `template.apk` to Git. `.gitignore` already excludes `apk-template/*.apk`.

5. Verify Embedded Bundle Loading

Install the template APK to a test device (it won’t have a bundle yet):

```bash
adb install -r apk-template/template.apk
```

Then package a bundle via the Desktop App (No Compile mode) and install the resulting APK. On first launch, the app should auto-detect and import the embedded bundle.

## Notes

- If you need to change package name or app icon/title for distribution, do that in the Android project before building the template APK.
- Keep the template APK updated with the same RN/native module versions as this repo to avoid runtime mismatches.
- Consider publishing the template APK as a GitHub Release asset, so content creators can download it without touching Android tools.
