# User Guide

Complete guide for using the Scripture Media Trial Content App.

## Table of Contents

- [Desktop Bundler](#desktop-bundler)
- [Mobile Player](#mobile-player)
- [Playback Limits](#playback-limits)
- [File Association](#file-association)
- [Troubleshooting](#troubleshooting)

## Desktop Bundler

The Desktop Bundler creates encrypted media bundles for secure distribution.

### Creating a Bundle

1. **Launch the Desktop App**
   ```bash
   npm run desktop
   ```

2. **Configure Bundle Information**
   - **Bundle Name**: Descriptive name (e.g., "Luke_Gospel_Trial")
   - **Device IDs**: Enter authorized device IDs, one per line
   - Get device IDs from the mobile app or via ADB:
     ```bash
     adb shell settings get secure android_id
     ```

3. **Set Playback Limits**

   **Basic Limits**:
   - **Maximum Plays per Reset Period**: How many times each file can be played
   - **Reset Interval**: Days, hours, minutes for the limit window

   **Advanced Limits** (optional):
   - **Minimum Interval Between Plays**: Required wait time between plays
   - **Maximum Total Plays Ever**: Absolute lifetime limit
   - **Bundle Expiration Date**: Date/time when bundle permanently locks

   **Playlist Limits** (optional):
   - **Max Items Per Session**: Limit unique files per session
   - **Session Reset Interval**: Time window for sessions
   - **Min Interval Between Items**: Wait between different files
   - **Max Total Items Played**: Lifetime limit on unique files

4. **Add Media Files**
   - Click "Add Media Files"
   - Select audio or video files
   - Supported formats: MP3, MP4, WAV, M4A, WebM, AVI, MOV
   - Multiple files can be selected

5. **Create Bundle**
   - Click "Create Bundle"
   - Select output directory
   - Wait for encryption and bundling to complete
   - A `.smbundle` file will be created

### Bundle Output

The `.smbundle` file contains:
- Encrypted media files
- Bundle configuration with limits and device restrictions
- All necessary metadata for mobile app

### Distributing Bundles

**Recommended methods**:
- Email (as attachment)
- Cloud storage (Google Drive, Dropbox, OneDrive)
- Messaging apps (WhatsApp, Telegram)
- USB transfer
- Direct file sharing

**Security notes**:
- Use secure channels when possible
- Don't post bundles publicly
- Track who receives which bundles
- Bundles only work on authorized devices

## Mobile Player

The Mobile Player opens and plays encrypted bundles on authorized Android devices.

### Installing the App

1. Build the APK:
   ```bash
   scripts/build_apk.sh --release
   ```

2. Transfer APK to device and install, or install via ADB:
   ```bash
   adb install app-release.apk
   ```

### Importing Bundles

**Automatic Import** (File Association):
1. Receive `.smbundle` file on your device
2. Tap the file in file manager, email, or messaging app
3. Select "Scripture Demo Player" when prompted
4. Bundle automatically imports and decrypts
5. Media becomes available

**Manual Import** (if needed):
1. Transfer `.smbundle` to device storage
2. Open file manager
3. Navigate to the file
4. Tap to open

### Playing Media

1. **Browse Media List**
   - All available media files are displayed
   - Shows title, type (audio/video), and playback status

2. **Check Playback Status**
   - Plays remaining in current window
   - Total plays remaining (if limit set)
   - Next reset time
   - Inter-play cooldown (if active)

3. **Play Media**
   - Tap "Play" button
   - Media plays in built-in player
   - Playback is automatically tracked

4. **Playback Controls**
   - Play/Pause
   - Seek forward/backward
   - Volume control
   - Fullscreen (video)

### Understanding Status Messages

**Available to play**:
- "3 / 5 plays left · resets in 8h 23m · 7 / 10 total"

**Temporarily blocked**:
- "Must wait 12 minutes between plays"
- "Play limit reached. Resets in 2h 15m"
- "Must wait 5 minutes between playing different items"

**Permanently blocked**:
- "Locked: Lifetime limit reached"
- "Locked: Bundle expired on [date]"
- "Time tampering detected. Bundle permanently locked"
- "Maximum unique items from playlist already played"

## Playback Limits

### Windowed Play Limits

**Purpose**: Control how many times media can be played within a time window.

**Example**: 3 plays per 24 hours
- User can play 3 times
- After 24 hours from first play, count resets
- Can play 3 more times

**Use cases**:
- Daily review limits
- Preventing content memorization
- Controlled exposure

### Minimum Interval Between Plays

**Purpose**: Enforce waiting period between successive plays of the same file.

**Example**: 15 minutes minimum
- User plays file
- Must wait 15 minutes
- Can play again

**Use cases**:
- Prevent rapid repeated plays
- Ensure thoughtful listening
- Space out content exposure

### Total Play Limit

**Purpose**: Set absolute maximum plays across all time.

**Example**: 10 total plays ever
- File can be played 10 times total
- After 10 plays, permanently locked
- Cannot be reset

**Use cases**:
- Trial content with strict limits
- Ensuring content isn't overused
- Permanent expiration after certain usage

### Bundle Expiration

**Purpose**: Lock bundle after specific date/time.

**Example**: Expires December 31, 2024 at 11:59 PM
- Bundle works normally until that time
- After expiration, permanently locked
- All media becomes unavailable

**Tamper Protection**:
- App detects if device clock is set backward
- If tampering detected, bundle permanently locks
- Prevents circumventing expiration

### Playlist-Level Limits

**Purpose**: Control overall usage across multiple files in a bundle.

#### Max Items Per Session
- Limits unique files that can be played in a session
- Example: 3 different files per 24 hours
- Already-played files can be replayed (per-file limits apply)

#### Minimum Interval Between Items
- Required wait time between playing different files
- Example: 10 minutes between switching files
- Does NOT apply when replaying same file

#### Max Total Items Played
- Lifetime limit on unique files from bundle
- Example: 5 different files total, ever
- After limit reached, no new files can be played
- Previously played files can still be replayed

### Combining Limits

Multiple limits work together. The most restrictive applies.

**Example Configuration**:
```
Per-file:
- Max plays: 3 per 24 hours
- Min interval: 5 minutes
- Total plays: 6 ever

Playlist:
- Max items per session: 3 per 24 hours
- Min interval between items: 10 minutes
- Max total items: 10 ever

Result:
- Can play 3 different files per day
- Each file: max 3 plays per day, 6 total ever
- Must wait 5 min between plays of same file
- Must wait 10 min between different files
- After 10 unique files played, no new files available
```

## File Association

Android automatically associates `.smbundle` files with the app.

### Supported Sources

- **File Managers**: Files app, My Files, etc.
- **Email**: Gmail, Outlook, etc.
- **Messaging**: WhatsApp, Telegram, Signal, etc.
- **Cloud Storage**: Google Drive, Dropbox, OneDrive
- **Web Downloads**: Chrome, Firefox, etc.

### How It Works

1. Receive or download `.smbundle` file
2. Tap the file
3. Android shows app chooser with "Scripture Demo Player"
4. Select the app
5. Bundle automatically processes
6. Media becomes available

### Setting as Default

1. Open a `.smbundle` file
2. Select "Scripture Demo Player"
3. Tap "Always" instead of "Just once"
4. Future `.smbundle` files open automatically

## Troubleshooting

### Desktop App Issues

#### App Won't Start

**Solutions**:
1. Reinstall dependencies:
   ```bash
   cd desktop-app
   rm -rf node_modules package-lock.json
   npm install
   npm start
   ```

2. Check Node version:
   ```bash
   node --version  # Should be 16.x or higher
   ```

3. Check for port conflicts:
   - Close other Electron apps
   - Restart your computer

#### Bundle Creation Fails

**Check**:
- Sufficient disk space (need 2x media size)
- Valid device IDs (no special characters)
- Output directory has write permissions
- Media files are not corrupted

**Solutions**:
- Try smaller media files first
- Verify media files play normally
- Use different output directory
- Check error messages in console

#### Media Files Not Encrypting

**Check**:
- Media file formats are supported
- Files are readable
- Files are not already encrypted

### Mobile App Issues

#### App Won't Install

**Solutions**:
1. Check device connection:
   ```bash
   adb devices
   ```

2. Clean build:
   ```bash
   cd mobile_app
   flutter clean
   flutter pub get
   flutter run
   ```

3. Restart ADB:
   ```bash
   adb kill-server
   adb start-server
   ```

#### Bundle Won't Import

**Possible causes**:
- Device not authorized (check device ID)
- Bundle file corrupted (re-download)
- Bundle expired
- File association not working

**Solutions**:
1. Verify your device ID is in authorized list
2. Re-download bundle file
3. Check bundle expiration date
4. Try opening manually from file manager
5. Reinstall app:
   ```bash
   scripts/build_apk.sh --uninstall-first
   ```

#### Media Won't Play

**Common causes**:
- **"Device not authorized"**: Your device ID not in bundle
- **"Playback limit reached"**: Wait for reset time
- **"Must wait X minutes"**: Minimum interval not elapsed
- **"Locked: Bundle expired"**: Bundle past expiration date
- **"Time tampering detected"**: Device clock was set backward

**Solutions**:
- Contact content creator to authorize your device
- Wait for reset interval to pass
- Wait for minimum interval to elapse
- Get new bundle with later expiration
- Avoid changing device clock

#### Media Player Issues

**Video won't play**:
- Check supported formats (MP4, WebM, AVI, MOV)
- Ensure file is not corrupted
- Try different video file
- Check device codec support

**Audio issues**:
- Check volume settings
- Verify audio file format (MP3, WAV, M4A)
- Try different audio file
- Restart app

#### File Association Not Working

**Solutions**:
1. Reinstall app:
   ```bash
   scripts/build_apk.sh --uninstall-first
   ```

2. Clear default app settings:
   - Settings → Apps → Default apps
   - Clear defaults for file types
   - Try opening file again

3. Check intent filters:
   ```bash
   adb shell pm dump net.iraobi.scripturedemoplayer | grep -A 20 "intent-filter"
   ```

### General Issues

#### "Time Tampering Detected"

**Cause**: Device clock was set backward after using bundle.

**Solution**: 
- This is a permanent lock
- Cannot be undone
- Need new bundle from content creator
- Don't change device clock

#### "Bundle Expired"

**Cause**: Current date/time past bundle expiration.

**Solution**:
- Bundle is permanently locked
- Need new bundle with later expiration
- Contact content creator

#### "Lifetime Limit Reached"

**Cause**: Maximum total plays exceeded.

**Solution**:
- Permanent lock, cannot be reset
- Need new bundle if more plays needed
- Contact content creator

### Getting More Help

1. Check relevant documentation:
   - [GETTING_STARTED.md](GETTING_STARTED.md) - Setup and basics
   - [TECHNICAL.md](TECHNICAL.md) - Architecture and security
   - [COMMUNITY.md](COMMUNITY.md) - FAQ and support

2. Check GitHub issues:
   - Search existing issues
   - Open new issue if needed

3. Enable debug logging:
   ```bash
   flutter logs
   # or
   adb logcat | grep Scripture
   ```

4. Collect information for bug reports:
   - Device model and Android version
   - App version
   - Steps to reproduce
   - Error messages
   - Screenshots if applicable
