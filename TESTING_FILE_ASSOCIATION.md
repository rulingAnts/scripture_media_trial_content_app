# Testing .smbundle File Association on Android

## Prerequisites

1. Build and install the APK on an Android device or emulator
2. Have at least one `.smbundle` file available for testing

## Building the APK

Use the provided build script:

```bash
cd scripture_media_trial_content_app
scripts/build_apk.sh
```

For a release build:
```bash
scripts/build_apk.sh --release
```

## Test Scenarios

### Test 1: Opening from File Manager

**Steps:**
1. Transfer a `.smbundle` file to your Android device (via USB, cloud storage, or email)
2. Open your device's file manager (Files, My Files, etc.)
3. Navigate to the location of the `.smbundle` file
4. Tap on the `.smbundle` file

**Expected Result:**
- Android shows a chooser dialog with "Scripture Demo Player" as an option
- After selecting the app, it launches and begins processing the bundle
- The status message shows "Extracting bundle..." followed by import progress
- If successful, the media from the bundle is available for playback

**First-time behavior:**
- On first use, you may see an "Open with" dialog
- Select "Scripture Demo Player"
- Optionally tap "Always" to make it the default handler

### Test 2: Sharing from WhatsApp

**Steps:**
1. Have someone send you a `.smbundle` file via WhatsApp
2. In WhatsApp, tap on the received file
3. Tap the share/forward icon or long-press and select "Share"
4. Look for "Scripture Demo Player" in the share sheet

**Expected Result:**
- Scripture Demo Player appears in the share options
- After selecting it, the app launches
- The bundle is automatically processed
- Media becomes available for playback

### Test 3: Opening from Email

**Steps:**
1. Send yourself an email with a `.smbundle` file attached
2. Open the email on your Android device
3. Tap on the attachment
4. Select "Scripture Demo Player" from the options

**Expected Result:**
- App launches with the file
- Bundle processing begins automatically
- Media is imported successfully

### Test 4: Setting as Default Handler

**Steps:**
1. Open Android Settings
2. Go to Apps → Default apps → Opening links (path may vary by Android version)
3. Find "Scripture Demo Player"
4. Enable "Open supported links"

**Alternative method:**
1. Open a `.smbundle` file
2. In the chooser dialog, select "Scripture Demo Player"
3. Tap "Always" instead of "Just once"

**Expected Result:**
- Future `.smbundle` files open directly in Scripture Demo Player
- No chooser dialog is shown (unless reset)

### Test 5: Error Handling

**Steps:**
1. Try to share or open a non-.smbundle file with the app
2. Try to share a corrupted or invalid `.smbundle` file

**Expected Result:**
- For non-.smbundle files: Status shows "Please select a .smbundle file."
- For invalid bundles: Appropriate error messages are displayed
- App remains stable and doesn't crash

## Verifying File Association

To check if the file association is working:

```bash
# On your development machine, check what can open .smbundle files
adb shell pm dump net.iraobi.scripturedemoplayer | grep -A 20 "intent-filter"
```

You should see the VIEW and SEND intent filters listed.

## Troubleshooting

### File Association Not Working

If `.smbundle` files don't show Scripture Demo Player as an option:

1. **Reinstall the app:**
   ```bash
   scripts/build_apk.sh --uninstall-first
   ```

2. **Clear default apps:**
   - Settings → Apps → Scripture Demo Player → Open by default
   - Tap "Clear defaults"

3. **Check Android version:**
   - File association may behave differently on older Android versions
   - Test on Android 7.0+ for best results

### App Doesn't Launch When File is Opened

1. **Check logcat for errors:**
   ```bash
   adb logcat | grep -i "scripture\|intent"
   ```

2. **Verify intent filters in manifest:**
   ```bash
   aapt dump xmltree mobile_app/build/app/outputs/flutter-apk/app-debug.apk AndroidManifest.xml | grep -A 20 "intent-filter"
   ```

3. **Test with a known-good `.smbundle` file:**
   - Ensure the file is not corrupted
   - Verify it has the `.smbundle` extension (case-insensitive)

### Bundle Processing Fails

1. **Check device ID authorization:**
   - Verify the bundle was created for this device ID
   - Check device ID in app: Tap the info icon in the app bar

2. **Review error messages:**
   - "Device not authorized" → Bundle wasn't created for this device
   - "Bundle previously used" → Bundle was already imported
   - "Invalid bundle config" → Bundle file is corrupted or invalid

## Expected Behavior Summary

| Scenario | Expected Outcome |
|----------|------------------|
| First time opening .smbundle | Chooser dialog appears |
| After selecting "Always" | Files open directly in app |
| Sharing from WhatsApp | App appears in share sheet |
| Opening from file manager | App launches and processes file |
| Invalid file extension | Error message displayed |
| Corrupted bundle | Appropriate error shown, no crash |

## Additional Testing

For thorough testing, try:
- Different file manager apps (Google Files, Total Commander, etc.)
- Different sharing sources (Gmail, Drive, Slack, etc.)
- Different Android versions (7.0+)
- Different device manufacturers (Samsung, Google Pixel, etc.)

## Notes

- File association is Android-specific; iOS would require separate implementation
- The app maintains all existing security checks during shared file processing
- Files received via sharing are processed with the same validation as manually imported files
