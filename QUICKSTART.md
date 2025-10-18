# Quick Start Guide

Get up and running with the Scripture Media Trial Content App in minutes!

## Prerequisites Check

Before starting, ensure you have:

- [ ] Node.js 16.x or higher (`node --version`)
- [ ] npm 8.x or higher (`npm --version`)
- [ ] For Android development:
  - [ ] Android Studio installed
  - [ ] JDK 11 or higher (`java -version`)
  - [ ] Android SDK Platform 33+

## 5-Minute Desktop Setup

### 1. Install Dependencies

```bash
cd scripture_media_trial_content_app
npm install
```

This installs all dependencies for desktop app, mobile app, and shared library.

### 2. Launch Desktop Bundler

```bash
npm run desktop
```

The Desktop Bundler window will open. You're ready to create bundles!

## 10-Minute Mobile Setup (Android)

### 1. Set Environment Variables

**macOS/Linux:**
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

**Windows:**
```cmd
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set PATH=%PATH%;%ANDROID_HOME%\platform-tools
```

### 2. Connect Device or Start Emulator

**Physical Device:**
- Enable USB debugging in Developer Options
- Connect via USB
- Verify: `adb devices`

**Emulator:**
- Open Android Studio
- AVD Manager > Create/Start virtual device

### 3. Start Metro Bundler

```bash
cd mobile-app
npm start
```

Keep this terminal running.

### 4. Install App (New Terminal)

```bash
cd mobile-app
npm run android
```

The app will install and launch on your device!

## Your First Bundle

### Step 1: Get Device ID

1. Launch mobile app on your test device
2. Note the Device ID shown on screen
3. Copy it (e.g., "abc123def456789")

### Step 2: Create Bundle

1. Open Desktop Bundler
2. **Bundle Name**: Enter "Test_Bundle"
3. **Device IDs**: Paste your device ID
4. **Playback Limits**: 
   - Max plays: 3
   - Reset: 24 hours
5. **Add Media**: Click "Add Media Files"
   - Select an MP3 or MP4 file
6. **Create**: Click "Create Bundle"
7. Select output directory
8. Wait for completion

### Step 3: Transfer Bundle

**Option A: USB Transfer**
```bash
# From your computer
adb push /path/to/bundle /sdcard/Download/Test_Bundle
```

**Option B: Manual Copy**
- Connect device to computer
- Copy bundle folder to device storage
- Suggested location: `/sdcard/Download/`

### Step 4: Import in Mobile App

**Note:** Currently requires manual implementation of import UI.

For testing, you can use ADB to place files:
```bash
# Navigate to bundle directory
cd /path/to/Test_Bundle

# Copy bundle config
adb push bundle.json /sdcard/Download/

# Copy media files
adb push media/ /sdcard/Download/media/
```

Then modify the mobile app to load from this location for testing.

## Troubleshooting

### Desktop App Won't Start

```bash
cd desktop-app
rm -rf node_modules package-lock.json
npm install
npm start
```

### Android Build Fails

```bash
cd mobile-app/android
./gradlew clean
cd ..
npm run android
```

### Metro Bundler Issues

```bash
cd mobile-app
npm start -- --reset-cache
```

### Device Not Detected

```bash
# Check connection
adb devices

# Restart ADB server
adb kill-server
adb start-server
```

## Next Steps

### Learn More

1. Read [USAGE.md](USAGE.md) for detailed usage instructions
2. Review [ARCHITECTURE.md](ARCHITECTURE.md) to understand the system
3. Check [SECURITY.md](SECURITY.md) for security considerations

### Customize

- Adjust playback limits for your use case
- Add multiple device IDs for reviewers
- Organize bundles by content type
- Create naming conventions

### Deploy

- Build release APK: `cd mobile-app && npm run build`
- Build desktop app: `cd desktop-app && npm run build`
- Distribute to your team

## Common Tasks

### Create a New Bundle

```bash
npm run desktop
# Use UI to create bundle
```

### Test on Android

```bash
# Terminal 1
cd mobile-app && npm start

# Terminal 2
cd mobile-app && npm run android
```

### View Android Logs

```bash
adb logcat | grep ScriptureMedia
```

### Check App Storage

```bash
adb shell
cd /data/data/com.scriptureMedia/files
ls -la
```

## Getting Help

- **Issues**: Open a GitHub issue
- **Questions**: Check existing documentation
- **Security**: Email privately (don't post publicly)

## Quick Reference

### Useful Commands

```bash
# Install all dependencies
npm install

# Run desktop app
npm run desktop

# Run mobile app
npm run mobile

# Build desktop (Windows)
cd desktop-app && npm run build:win

# Build desktop (macOS)
cd desktop-app && npm run build:mac

# Build Android APK
cd mobile-app && npm run build

# View React Native logs
cd mobile-app && npm start -- --verbose

# Clear all caches
cd mobile-app && npm start -- --reset-cache
```

### File Locations

```
Root package.json         - Workspace configuration
shared/                   - Common utilities
desktop-app/src/          - Electron app
mobile-app/src/           - React Native app
mobile-app/android/       - Android native code
examples/                 - Example files
```

### Important Files

```
bundle.json              - Bundle configuration
*.enc                    - Encrypted media files
README.txt               - Bundle instructions
App.js                   - Mobile app main UI
main.js                  - Desktop app backend
```

## Success Checklist

- [ ] Desktop app opens and shows UI
- [ ] Can select media files
- [ ] Can create bundle with device ID
- [ ] Bundle folder created with files
- [ ] Mobile app installs on device
- [ ] App shows device ID
- [ ] Can copy bundle to device
- [ ] Ready for production use

Congratulations! You're ready to create and distribute secure media bundles! 🎉
