# Troubleshooting Guide

This guide helps you diagnose and fix common issues with the Scripture Media Trial Content App.

## Desktop App Issues

### Desktop App Won't Start

**Symptoms:**
- Electron window doesn't open
- Error in console
- White screen

**Solutions:**

1. **Reinstall Dependencies**
   ```bash
   cd desktop-app
   rm -rf node_modules package-lock.json
   npm install
   npm start
   ```

2. **Check Node Version**
   ```bash
   node --version  # Should be 16.x or higher
   npm --version   # Should be 8.x or higher
   ```

3. **Check for Port Conflicts**
   - Close other Electron apps
   - Restart your computer

4. **View Debug Console**
   - Set `NODE_ENV=development`
   - DevTools will open automatically

### Bundle Creation Fails

**Symptoms:**
- "Failed to create bundle" error
- Files not encrypted
- Output directory empty

**Solutions:**

1. **Check File Permissions**
   ```bash
   # macOS/Linux
   ls -la /path/to/output
   chmod -R 755 /path/to/output
   ```

2. **Verify Media Files**
   - Files must be readable
   - Supported formats: MP3, MP4, WAV, M4A, WebM, AVI, MOV
   - Check file isn't corrupted: try playing it

3. **Check Disk Space**
   - Need 2x media file size
   - Check: `df -h` (Unix) or `dir` (Windows)

4. **Validate Device IDs**
   - No special characters except alphanumeric
   - One ID per line
   - No empty lines

5. **Try Smaller Files First**
   - Test with a small (1-2MB) file
   - Gradually increase size

### UI Not Responding

**Symptoms:**
- Buttons don't work
- Form fields frozen
- Can't select files

**Solutions:**

1. **Reload the Window**
   - Cmd/Ctrl + R to reload
   - Or restart the app

2. **Check Console Errors**
   - Open DevTools (Cmd/Ctrl + Shift + I)
   - Look for JavaScript errors

3. **Clear Cache**
   ```bash
   rm -rf ~/Library/Application\ Support/scripture-media-desktop-app  # macOS
   rm -rf ~/.config/scripture-media-desktop-app                       # Linux
   rd /s %APPDATA%\scripture-media-desktop-app                       # Windows
   ```

## Mobile App Issues

### App Won't Install

**Symptoms:**
- `npm run android` fails
- APK installation error
- Build fails

**Solutions:**

1. **Clean Build**
   ```bash
   cd mobile-app/android
   ./gradlew clean
   cd ..
   npm run android
   ```

2. **Check Device Connection**
   ```bash
   adb devices
   # Should show your device
   ```

3. **Restart ADB**
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```

4. **Check Android SDK**
   ```bash
   echo $ANDROID_HOME  # Should point to SDK
   ls $ANDROID_HOME/platforms  # Should have android-33 or higher
   ```

5. **Update Dependencies**
   ```bash
   cd mobile-app
   rm -rf node_modules package-lock.json
   npm install
   ```

### Metro Bundler Errors

**Symptoms:**
- Red error screen
- "Unable to resolve module"
- "Module not found"

**Solutions:**

1. **Reset Cache**
   ```bash
   cd mobile-app
   npm start -- --reset-cache
   ```

2. **Clear Watchman**
   ```bash
   watchman watch-del-all
   ```

3. **Clean Metro Cache**
   ```bash
   rm -rf /tmp/metro-*
   rm -rf /tmp/haste-*
   ```

4. **Reinstall Dependencies**
   ```bash
   cd mobile-app
   rm -rf node_modules
   npm install
   ```

### Device ID Not Showing

**Symptoms:**
- Blank screen
- "Unable to get device ID" error
- Crash on launch

**Solutions:**

1. **Check Permissions**
   - App needs READ_PHONE_STATE permission
   - Check Android settings > Apps > Scripture Media > Permissions

2. **Check react-native-device-info**
   ```bash
   cd mobile-app
   npm ls react-native-device-info
   ```

3. **Rebuild Native Modules**
   ```bash
   cd mobile-app/android
   ./gradlew clean
   cd ..
   npm run android
   ```

### Bundle Won't Load

**Symptoms:**
- "Device not authorized" error
- "Invalid bundle" error
- "Failed to load bundle"

**Solutions:**

1. **Verify Device ID**
   - Check device ID in app
   - Compare with bundle.json allowedDeviceIds
   - IDs must match exactly

2. **Check Bundle Structure**
   ```bash
   ls bundle_directory/
   # Should have: bundle.json, media/, README.txt
   ```

3. **Validate bundle.json**
   - Must be valid JSON
   - Check with: `cat bundle.json | json_pp`
   - Use example-bundle-config.json as reference

4. **Check File Permissions**
   ```bash
   adb shell
   cd /sdcard/Download/bundle_name
   ls -la
   # Files should be readable (r-- at minimum)
   ```

### Media Won't Play

**Symptoms:**
- "Playback limit reached" (but shouldn't be)
- "Media file not found"
- "Failed to decrypt"

**Solutions:**

1. **Check Playback History**
   - Playback counts stored in AsyncStorage
   - May need to clear app data if testing

2. **Verify Media Files Imported**
   ```bash
   adb shell
   cd /data/data/com.scriptureMedia/files/secure_media
   ls -la
   # Should see .enc files
   ```

3. **Check Device Key**
   - Device ID must match bundle creation
   - Factory reset changes device ID
   - Try re-creating bundle

4. **Clear Temp Files**
   ```bash
   adb shell
   cd /data/data/com.scriptureMedia/cache
   rm -rf *
   ```

5. **Reinstall App** (if all else fails)
   - Uninstall: `adb uninstall com.scriptureMedia`
   - Reinstall: `npm run android`
   - Re-import bundle

### Storage Issues

**Symptoms:**
- "Insufficient storage" error
- Files not saving
- Import fails

**Solutions:**

1. **Check Available Space**
   ```bash
   adb shell df /data
   # Need at least 2x media size
   ```

2. **Clear App Cache**
   ```bash
   adb shell
   pm clear com.scriptureMedia --cache-only
   ```

3. **Remove Old Bundles**
   - In app, clear old bundles
   - Or manually: `adb shell rm -rf /data/data/com.scriptureMedia/files/secure_media`

## Common Error Messages

### "ENOENT: no such file or directory"

**Cause:** File path doesn't exist

**Solution:**
- Check file path is correct
- Use absolute paths
- Verify file wasn't moved/deleted

### "Cannot read property 'X' of undefined"

**Cause:** JavaScript object is null/undefined

**Solution:**
- Check that bundle is loaded
- Verify data structure matches expected format
- Look at previous error for root cause

### "Network request failed"

**Cause:** Attempting network operation (shouldn't happen)

**Solution:**
- This app should work offline
- Check for unintended network calls
- Verify no external dependencies

### "Permission denied"

**Cause:** File system permission issue

**Solution:**
- Check app permissions in Android settings
- Verify file ownership and permissions
- Try running with elevated permissions (development only)

### "Failed to decrypt"

**Cause:** Wrong encryption key or corrupted file

**Solution:**
- Verify device ID matches bundle
- Check bundle wasn't corrupted during transfer
- Re-create bundle with correct device ID
- Verify entire bundle directory was copied

## Performance Issues

### Desktop App Slow

**Symptoms:**
- Laggy UI
- Slow encryption
- High CPU usage

**Solutions:**

1. **Process Smaller Batches**
   - Create bundles with fewer files
   - Encrypt files individually

2. **Close Other Apps**
   - Free up CPU and memory

3. **Check File Sizes**
   - Very large files (>100MB) take time
   - Progress indicators help manage expectations

### Mobile App Slow

**Symptoms:**
- Slow playback start
- Laggy UI
- Battery drain

**Solutions:**

1. **Clear Temp Files**
   - Use app cleanup feature
   - Or: `adb shell pm clear com.scriptureMedia --cache-only`

2. **Reduce Bundle Size**
   - Fewer media files per bundle
   - Lower bitrate/resolution for media

3. **Check Device Storage**
   - Low storage slows everything
   - Free up space: delete old files

4. **Update App**
   - Get latest version
   - Performance improvements in newer versions

## Development Issues

### React Native Build Fails

**Symptoms:**
- Gradle errors
- JDK version mismatch
- Missing dependencies

**Solutions:**

1. **Check JDK Version**
   ```bash
   java -version  # Should be 11 or higher
   ```

2. **Update Gradle Wrapper**
   ```bash
   cd mobile-app/android
   ./gradlew wrapper --gradle-version=8.0
   ```

3. **Sync Gradle Files**
   - In Android Studio: File > Sync Project with Gradle Files

4. **Clear Gradle Cache**
   ```bash
   rm -rf ~/.gradle/caches
   ```

### Electron Build Fails

**Symptoms:**
- electron-builder errors
- Missing dependencies
- Code signing issues

**Solutions:**

1. **Update electron-builder**
   ```bash
   cd desktop-app
   npm install electron-builder@latest
   ```

2. **Simplify Build**
   - Build for current platform only
   - Skip code signing for testing

3. **Check Build Config**
   - Verify package.json build section
   - Ensure all files are included

## Getting More Help

### Gather Diagnostic Info

Before asking for help, collect:

1. **System Info**
   ```bash
   node --version
   npm --version
   java -version
   echo $ANDROID_HOME
   ```

2. **Error Messages**
   - Full error text
   - Stack traces
   - Console output

3. **Steps to Reproduce**
   - What you did
   - What you expected
   - What actually happened

4. **Environment**
   - OS and version
   - Device/emulator details
   - App version

### Where to Ask

1. **GitHub Issues**: For bugs and feature requests
2. **Documentation**: Re-read relevant guides
3. **Examples**: Check example files
4. **Community**: Search for similar issues

### What to Include in Issue Report

```markdown
## Description
Brief description of the issue

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: [e.g., macOS 12.0, Windows 11, Ubuntu 22.04]
- Node: [e.g., v16.14.0]
- npm: [e.g., 8.5.0]
- App Version: [e.g., 1.0.0]
- Device: [e.g., Pixel 6, Android 13]

## Error Messages
```
Paste error messages here
```

## Screenshots
If applicable, add screenshots

## Additional Context
Any other relevant information
```

## Preventing Issues

### Best Practices

1. **Keep Dependencies Updated**
   ```bash
   npm outdated
   npm update
   ```

2. **Test Before Distributing**
   - Create test bundle
   - Verify on actual device
   - Check all features work

3. **Use Consistent Naming**
   - Descriptive bundle names
   - Track device IDs properly
   - Document your workflow

4. **Regular Backups**
   - Keep original media files
   - Save bundle configurations
   - Document device authorizations

5. **Monitor Storage**
   - Check available space
   - Clean up old bundles
   - Archive completed projects

## Emergency Procedures

### Complete Reset (Desktop)

```bash
cd desktop-app
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

### Complete Reset (Mobile)

```bash
# Uninstall app
adb uninstall com.scriptureMedia

# Clean project
cd mobile-app
rm -rf node_modules package-lock.json android/.gradle
npm cache clean --force

# Reinstall
npm install
cd android && ./gradlew clean && cd ..
npm run android
```

### Start Fresh

If all else fails:

1. Clone repository again
2. Follow QUICKSTART.md from beginning
3. Test with minimal example first
4. Gradually add complexity

Remember: Most issues are resolved by:
1. Cleaning caches
2. Reinstalling dependencies
3. Restarting services
4. Reading error messages carefully
