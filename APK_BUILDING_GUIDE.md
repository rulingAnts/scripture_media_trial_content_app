# APK Building Feature - Usage Guide

## Overview

The desktop app now has the ability to create complete Android APK files with embedded bundles, eliminating the need for separate bundle transfer and import steps.

## How It Works

### Traditional Workflow (Before)
1. Create bundle in desktop app
2. Transfer bundle to Android device manually
3. Import bundle in mobile app
4. Verify and play content

### New APK Workflow (Now)
1. Create bundle AND build APK in desktop app
2. Install APK directly on Android device
3. App automatically loads embedded bundle on first launch
4. Content is immediately available for playback

## Prerequisites

Before you can build APKs, ensure you have:
Before you can build APKs via the compile path, ensure you have:

1. **Node.js** 16.x or higher
2. **Android Studio** with Android SDK
3. **Java JDK** 11 or higher
4. **React Native CLI** (`npm install -g @react-native-community/cli`)
5. **ANDROID_HOME** environment variable set to your Android SDK path

## Using the APK Builder

### Step 1: Configure Your Bundle
1. Open the Desktop Bundler app
2. Enter **Bundle Name** (e.g., "Luke_Gospel_Trial")
3. Add **Device IDs** (one per line)
4. Set **Playback Limits** (max plays and reset interval)
5. Add **Media Files** (click "Add Media Files")

### Step 2: Choose APK Output
1. In the **Output Options** section, select **"Build APK with Embedded Bundle"**
2. Enter an **App Name** (e.g., "Luke_Gospel_App")
3. The system will automatically check if your build environment is ready.

### Step 3: Build the APK
1. Click **"Build APK"** button
2. Select an output directory for the APK file
3. Wait for the build process to complete (may take several minutes)
4. The APK will be saved with a timestamp: `AppName_2024-10-18T10-30-00.apk`

### Step 3 (Alternative): Package from Template (No Compile)

1. Obtain a prebuilt Template APK (maintainer builds once)
2. Place it at `apk-template/template.apk` (ignored by Git)
3. In Output Options, leave the Template APK path empty to use the default, or provide a custom path
4. Click “Package from Template (No Compile)”
5. Optionally provide signing info (keystore path/alias/passwords) for automatic signing

## Environment Status Indicators

### ✅ Ready (Green)
- All tools are available
- APK building is enabled

### ⚠️ Issues Found (Red)  
- Missing or misconfigured tools
- APK building is disabled
- Follow the provided instructions to resolve issues

## Installation and Testing

### Installing the APK
```bash
# Install via ADB
adb install path/to/your-app.apk

# Or use Android Studio device manager
# Or transfer APK to device and install manually
```

### What Happens on First Launch
1. App detects embedded bundle automatically
2. Verifies device authorization against embedded device IDs
3. Imports encrypted media files to secure storage
4. Content becomes immediately available for playback

## Technical Details

### How Embedding Works
- Bundle files are placed in the APK's `assets/bundle/` directory
- `bundle.json` contains the configuration
- `media/` folder contains encrypted media files
- `.embedded` marker file indicates this is an embedded bundle

### Security
- Device authorization still applies - only listed device IDs can access content
- Media files remain encrypted in the APK
- Decryption happens only during playback on authorized devices

### File Structure in APK
```
assets/
├── bundle/
│   ├── .embedded          # Marker file
│   ├── bundle.json        # Bundle configuration
│   └── media/             # Encrypted media files
│       ├── uuid1.enc
│       └── uuid2.enc
```

## Troubleshooting

### Build Environment Issues

**"React Native CLI not found"**
```bash
npm install -g @react-native-community/cli
```

**"ANDROID_HOME environment variable not set"**
```bash
# macOS/Linux
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Windows
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set PATH=%PATH%;%ANDROID_HOME%\platform-tools
```

**"Android project not initialized"**
```bash
cd mobile-app
npx react-native run-android
# This initializes the Android project files
```

If you only need the no-compile path, skip environment setup and use a Template APK instead. See `scripts/BUILD_TEMPLATE_APK.md` to produce one (maintainer step).

**"Java JDK not found"**
- Install JDK 11 or higher from Oracle or OpenJDK
- Ensure `java -version` works in terminal

### Build Failures

**Gradle build fails**
- Check that Android SDK Platform 33+ is installed
- Ensure you have enough disk space (builds can be large)
- Try cleaning: `cd mobile-app/android && ./gradlew clean`

**APK build times out**
- First builds can take 10+ minutes
- Subsequent builds are faster due to caching
- Ensure good internet connection for dependency downloads

## Benefits of APK Building

1. **Simplified Distribution**: Single APK file instead of separate app + bundle
2. **Reduced User Steps**: No manual bundle import required
3. **Improved Security**: Bundle is embedded and validated at build time
4. **Professional Deployment**: Standard Android app installation process
5. **Version Control**: Each APK includes bundle version and timestamp

## Limitations

1. **Build Environment**: Requires full Android development setup
2. **Build Time**: Initial builds can take 10+ minutes
3. **File Size**: APK includes both app and bundle content
4. **Single Bundle**: Each APK contains one specific bundle
5. **Device Specific**: Still requires device ID authorization

## Next Steps

- Test the APK on your target devices
- Verify content plays correctly with limits enforced
- Consider creating different APKs for different device groups
- Document your build and distribution process