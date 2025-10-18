# Usage Guide

## Desktop Bundler App

The Desktop Bundler App allows you to create secure media bundles that can only be played on specific authorized devices.

### Creating a Bundle

1. **Launch the Desktop App**
   - Run the application from your desktop or via `npm run desktop`

2. **Configure Bundle**
   - Enter a descriptive **Bundle Name** (e.g., "Luke_Gospel_Trial")
   - This name will be used to identify the bundle

3. **Add Authorized Devices**
   - Enter **Device IDs** in the text area, one per line
   - Each device ID uniquely identifies an Android device
   - Only devices with these IDs will be able to access the content
   - See "Getting Device IDs" section below

4. **Set Playback Limits**
   - **Maximum Plays per File**: How many times each media file can be played
   - **Reset Interval (hours)**: Time period after which the play count resets
   - Example: Max plays = 3, Reset = 24 hours means each file can be played 3 times per day

5. **Add Media Files**
   - Click "Add Media Files" button
   - Select audio or video files (MP3, MP4, WAV, M4A, WebM, AVI, MOV)
   - Multiple files can be selected at once
   - Files will be encrypted and secured in the bundle

6. **Create Bundle**
   - Click "Create Bundle" button
   - Select an output directory for the bundle
   - The app will:
     - Encrypt all media files
     - Create bundle configuration
     - Generate README with instructions
   - Wait for the process to complete

7. **Bundle Output**
   - A folder with your bundle name will be created
   - Contents:
     - `bundle.json` - Bundle configuration (required)
     - `media/` - Encrypted media files (required)
     - `README.txt` - Instructions for use

### Getting Device IDs

To get a device ID from an Android device:

1. **Install the Mobile App** on the target device
2. **Launch the App** - it will display the Device ID on the welcome screen
3. **Copy the Device ID** and add it to the Desktop Bundler's authorized devices list

Alternatively, you can use ADB (Android Debug Bridge):
```bash
adb shell settings get secure android_id
```

## Mobile App

The Mobile App plays media content from bundles created by the Desktop Bundler.

### First Time Setup

1. **Install the App** on your Android device
2. **Launch the App** - you'll see:
   - Your unique Device ID
   - A message indicating no bundle is loaded

3. **Share Your Device ID** with the content creator so they can authorize your device

### Loading a Bundle

1. **Transfer the Bundle** to your device:
   - Copy the entire bundle folder to your device storage
   - Use USB, cloud storage, or any file transfer method
   - Recommended location: `/sdcard/Download/` or `/sdcard/Documents/`

2. **Import the Bundle** (Implementation Note: This requires adding an import feature to the mobile app)
   - In the app, tap "Import Bundle"
   - Navigate to the bundle folder
   - Select the `bundle.json` file
   - The app will:
     - Verify device authorization
     - Import and decrypt media files
     - Display available content

### Playing Media

1. **View Media List**
   - All available media files are displayed
   - Each shows:
     - Title
     - Type (audio/video)
     - Play count (e.g., "Plays: 2/3")
     - Remaining plays
     - Next reset time (if limit reached)

2. **Play a File**
   - Tap "Play" on any available media file
   - The media will play in the built-in player
   - Playback is automatically recorded

3. **Playback Restrictions**
   - If play limit is reached, the "Play" button is disabled
   - A message shows when the limit will reset
   - After the reset time, plays become available again

4. **Stop Playback**
   - Tap "Stop" to end playback
   - Temporary files are cleaned up automatically

### Security Features

The mobile app includes several security features:

1. **Device Binding**
   - Content only works on authorized devices
   - Device ID is permanently tied to hardware
   - Cannot be spoofed or transferred

2. **Encrypted Storage**
   - All media files are encrypted on disk
   - Decryption happens only during playback
   - Temporary files are cleared after use

3. **Playback Tracking**
   - Play counts are stored locally
   - Cannot be reset by uninstalling/reinstalling
   - Survives app updates

4. **Anti-Sharing**
   - Encrypted files cannot be shared or copied
   - Decrypted content exists only in memory during playback
   - No ability to export or extract media files

### Limitations

- **No Cloud Sync**: All data is stored locally
- **No Backup**: Bundle data cannot be backed up
- **Device Specific**: Content cannot be moved to another device
- **Internet Not Required**: App works completely offline

## Best Practices

### For Content Creators

1. **Test Bundles**: Create test bundles and verify on actual devices
2. **Keep Device IDs Secure**: Treat device IDs as confidential information
3. **Document Devices**: Keep a record of which device IDs belong to which users
4. **Reasonable Limits**: Set playback limits that are fair but protective
5. **Backup Source Files**: Keep original media files in a secure location

### For Content Users

1. **Don't Share Your Device ID**: This is your unique authorization
2. **Keep the App Updated**: Install updates when available
3. **Don't Uninstall**: Uninstalling may cause loss of playback history
4. **Report Issues**: Contact content creator if bundles don't work

## Workflow Example

### Scenario: Sharing a trial Gospel recording

1. **Content Creator** (using Desktop App):
   - Creates bundle "John_Gospel_Trial"
   - Adds device IDs for 5 reviewers
   - Sets limit: 3 plays per 24 hours
   - Adds 10 audio chapters
   - Creates bundle in `/bundles/John_Gospel_Trial/`

2. **Distribution**:
   - Zips the bundle folder
   - Shares via secure email or cloud storage
   - Each reviewer downloads and extracts

3. **Reviewer** (using Mobile App):
   - Launches app, notes Device ID
   - Confirms their ID is authorized
   - Copies bundle to device storage
   - Imports bundle in app
   - Plays content (max 3 times per file per day)

4. **Review Period**:
   - Reviewers provide feedback
   - Creator can create updated bundles with changes
   - New bundles replace old ones

5. **Post-Review**:
   - Reviewers can delete bundles when review is complete
   - Content creator proceeds with official release

## Troubleshooting

### Desktop App

**"Bundle creation failed"**
- Check that all media files are accessible
- Verify device IDs are valid (no special characters)
- Ensure output directory has write permissions

**"Failed to encrypt media"**
- Check available disk space
- Verify media files are not corrupted
- Try smaller media files first

### Mobile App

**"Device not authorized"**
- Verify your device ID is in the authorized list
- Check that you're using the correct bundle
- Contact content creator to authorize your device

**"Playback limit reached"**
- Wait for the reset interval to pass
- Check the "Next reset time" displayed
- Contact content creator if limits need adjustment

**"Media file not found"**
- Ensure entire bundle folder was copied
- Check that media folder contains .enc files
- Re-import the bundle

**"Failed to decrypt media"**
- Bundle may be corrupted during transfer
- Re-download and re-import the bundle
- Verify your device ID hasn't changed (rare)
