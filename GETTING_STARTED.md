# Getting Started

Complete guide for setting up and using the Scripture Media Trial Content App for developers (we do have installers for the rest of us, see the ["Releases"](https://github.com/rulingAnts/scripture_media_trial_content_app/releases/latest) page).

## Quick Start (5 Minutes)

### Prerequisites

- Node.js 16.x or higher
- For Android development: Android Studio, Flutter SDK, JDK 11+

### Desktop App Setup

```bash
cd scripture_media_trial_content_app
npm install
npm run desktop
```

The Desktop Bundler window will open, ready to create bundles!

### Mobile App Setup (Android)

1. **Install Flutter SDK** (if not already installed)
   - Follow instructions at https://docs.flutter.dev/get-started/install

2. **Set Environment Variables**

   macOS/Linux:
   ```bash
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$PATH:$ANDROID_HOME/platform-tools
   ```

   Windows:
   ```cmd
   set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
   set PATH=%PATH%;%ANDROID_HOME%\platform-tools
   ```

3. **Build and Install**

   ```bash
   cd mobile_app
   flutter pub get
   flutter run
   ```

   Or use the build script:
   ```bash
   scripts/build_apk.sh
   ```

## Creating Your First Bundle

### Step 1: Get Device ID

1. Launch mobile app on your test device
2. Note the Device ID shown on screen
3. Copy it (e.g., "abc123def456789")

### Step 2: Create Bundle in Desktop App

1. Open Desktop Bundler
2. **Bundle Name**: Enter "Test_Bundle"
3. **Device IDs**: Paste your device ID (one per line)
4. **Playback Limits**: 
   - Max plays: 3
   - Reset interval: 1 day, 0 hours, 0 minutes
5. **Add Media**: Click "Add Media Files" and select audio/video files
6. **Create**: Click "Create Bundle" and select output directory

### Step 3: Transfer Bundle to Device

**Option A: Using the build script**
```bash
# Push bundle to device
adb push /path/to/bundle.smbundle /sdcard/Download/
```

**Option B: Manual transfer**
- Connect device via USB
- Copy `.smbundle` file to device storage
- Or share via email/WhatsApp

### Step 4: Open Bundle on Device

1. On your Android device, navigate to the `.smbundle` file in a file manager
2. Tap the file
3. Select "Scripture Demo Player" when prompted
4. The bundle will automatically import and media will be available

## Using the Apps

### Desktop Bundler

**Purpose**: Create encrypted media bundles with device restrictions and playback limits.

**Key Features**:
- Add media files (audio/video)
- Specify authorized device IDs
- Configure playback limits
- Set expiration dates
- Create encrypted `.smbundle` files

**Workflow**:
1. Configure bundle settings
2. Add authorized device IDs
3. Set playback restrictions
4. Add media files
5. Create and export bundle

### Mobile Player

**Purpose**: Play encrypted media from authorized bundles on authorized devices.

**Key Features**:
- Automatic bundle import via file association
- Device-specific decryption
- Playback limit enforcement
- Built-in media player
- Offline functionality

**Workflow**:
1. Receive `.smbundle` file
2. Tap to open (automatically imports)
3. Browse available media
4. Play within configured limits

## Playback Limits Explained

The app supports multiple types of playback restrictions:

### Per-File Limits

1. **Windowed Play Limits**: Maximum plays within a time window
   - Example: 3 plays per 24 hours

2. **Minimum Interval**: Required wait time between plays
   - Example: 15 minutes between each play

3. **Total Play Limit**: Absolute lifetime maximum
   - Example: 10 total plays ever

4. **Expiration Date**: Bundle locks after specific date/time
   - Example: Expires December 31, 2024

### Playlist-Level Limits

1. **Max Items Per Session**: Limit unique files per session
   - Example: 3 different files per day

2. **Session Reset Interval**: Time window for sessions
   - Example: 24 hours

3. **Minimum Interval Between Items**: Wait time between different files
   - Example: 5 minutes between switching files

4. **Max Total Items**: Lifetime limit on unique files played
   - Example: 10 different files total

5. **Playlist Expiration**: Separate expiration for playlist access

**Note**: The most restrictive limit always applies when combining limits.

## Common Tasks

### Building Release APK

```bash
cd mobile_app
flutter build apk --release
```

Or use the script:
```bash
scripts/build_apk.sh --release
```

### Building Desktop App for Distribution

```bash
cd desktop-app
npm run build:win   # Windows
npm run build:mac   # macOS
npm run build:linux # Linux
```

### Viewing Device Logs

```bash
flutter logs
# or
adb logcat | grep Scripture
```

## Troubleshooting

### Desktop App Won't Start

```bash
cd desktop-app
rm -rf node_modules package-lock.json
npm install
npm start
```

### Mobile App Build Fails

```bash
cd mobile_app
flutter clean
flutter pub get
flutter run
```

### Bundle Won't Import

**Check**:
- Is your device ID in the authorized list?
- Is the bundle file complete and not corrupted?
- Is the bundle expired?

### Media Won't Play

**Common causes**:
- Playback limit reached (wait for reset)
- Device not authorized
- Bundle expired
- Time tampering detected

## File Association

Android automatically associates `.smbundle` files with the app:

- Open from file managers
- Receive via WhatsApp, email, etc.
- Automatic import and processing
- No manual import needed

## Best Practices

### For Content Creators

1. **Test first**: Create test bundles before distribution
2. **Document limits**: Tell reviewers what restrictions are in place
3. **Set reasonable expiration**: Allow enough time for review
4. **Keep device IDs secure**: Treat as confidential information
5. **Backup source files**: Keep original media in secure location

### For Reviewers

1. **Check device ID**: Share it with content creator before they create bundle
2. **Respect limits**: Don't attempt to bypass playback restrictions
3. **Report issues**: Contact creator if bundles don't work
4. **Don't share**: Don't share bundles or device IDs with others

## Next Steps

- Read [USER_GUIDE.md](USER_GUIDE.md) for detailed usage instructions
- Review [TECHNICAL.md](TECHNICAL.md) for architecture and security details
- Check [COMMUNITY.md](COMMUNITY.md) for FAQ and contribution guidelines

## Getting Help

- **Documentation**: Read the user guide and technical docs
- **Issues**: Check existing GitHub issues
- **Questions**: Open a new GitHub issue
- **Security**: Report security issues privately (don't post publicly)
