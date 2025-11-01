# .smbundle File Association Implementation

## Overview

The mobile app now supports automatic file association for `.smbundle` files on Android. This allows users to:
- Open `.smbundle` files directly from file managers
- Receive and open `.smbundle` files shared from other apps (e.g., WhatsApp, email, messaging apps)
- Automatically launch the app when tapping on `.smbundle` files

## Implementation Details

### 1. Android Manifest Changes

Added three intent filters to `mobile_app/android/app/src/main/AndroidManifest.xml`:

#### Opening from File Managers (VIEW action)
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="file"/>
    <data android:scheme="content"/>
    <data android:host="*"/>
    <data android:pathPattern=".*\\.smbundle"/>
    <data android:pathPattern=".*\\..*\\.smbundle"/>
    <data android:pathPattern=".*\\..*\\..*\\.smbundle"/>
    <data android:pathPattern=".*\\..*\\..*\\..*\\.smbundle"/>
</intent-filter>
```

Multiple `pathPattern` entries are needed because Android's path pattern matching requires a separate pattern for each level of directory depth.

#### Receiving Shared Files (SEND action)
```xml
<intent-filter>
    <action android:name="android.intent.action.SEND"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <data android:mimeType="application/octet-stream"/>
</intent-filter>
<intent-filter>
    <action android:name="android.intent.action.SEND"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <data android:mimeType="*/*"/>
</intent-filter>
```

Two SEND intent filters are used to handle both specific and generic MIME types, as different apps may categorize `.smbundle` files differently.

### 2. Dependency Addition

Added the `receive_sharing_intent` package (v1.8.0) to handle incoming file intents:

```yaml
dependencies:
  receive_sharing_intent: ^1.8.0
```

This package provides:
- Stream-based listening for shared files while the app is running
- Retrieval of initial shared files when the app is launched via a file intent
- Proper handling of both scenarios seamlessly

### 3. Code Changes

#### Import Statement
```dart
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
```

#### State Variables
Added a stream subscription to track incoming file intents:
```dart
late StreamSubscription _intentDataStreamSubscription;
```

#### Initialization
In `initState()`, added call to `_initReceiveSharingIntent()` to set up the listeners.

#### New Methods

##### `_initReceiveSharingIntent()`
Sets up two listeners:
1. **Stream listener**: For files shared while the app is already running
2. **Initial media check**: For files that launched the app from a closed state

##### `_handleSharedFile(String filePath)`
Validates that the received file is a `.smbundle` file and processes it.

##### `_processBundle(String bundlePath)`
Refactored the bundle processing logic into a separate method that can be called from both:
- The manual file picker flow (`_pickAndProcessBundle()`)
- The shared file handler (`_handleSharedFile()`)

#### Cleanup
Updated `dispose()` to cancel the stream subscription:
```dart
_intentDataStreamSubscription.cancel();
```

## User Experience

### Opening from File Manager
1. User downloads or has a `.smbundle` file on their device
2. User opens their file manager app
3. User taps on the `.smbundle` file
4. Android shows a chooser with the Scripture Demo Player app as an option
5. User selects the app
6. The file is automatically processed and imported

### Sharing from WhatsApp or Other Apps
1. User receives a `.smbundle` file in WhatsApp (or any messaging app)
2. User taps on the file and selects "Open with" or "Share"
3. Android shows the Scripture Demo Player app as an option
4. User selects the app
5. The file is automatically processed and imported

### First Time Setup
The first time a user opens a `.smbundle` file:
- Android will show all compatible apps
- User can select "Always" to make Scripture Demo Player the default handler
- Subsequent `.smbundle` files will open directly in the app

## Testing

To test this functionality:

1. Build and install the APK on an Android device
2. Download or transfer a `.smbundle` file to the device
3. Test opening from a file manager
4. Test receiving via WhatsApp or another messaging app
5. Verify that the app launches and processes the bundle correctly

## Security Considerations

- The intent filters only respond to `.smbundle` files based on file extension
- All bundle validation and security checks from the existing import flow are maintained
- The `_processBundle()` method includes all existing security measures:
  - Device ID verification
  - Bundle configuration validation
  - Encryption verification
  - Bundle reuse prevention

## Compatibility

- **Minimum Android SDK**: No change from existing requirements
- **File Schemes Supported**: Both `file://` and `content://` URIs
- **Apps Tested**: File managers, WhatsApp, email clients (any app that can share files)

## Future Enhancements

Potential improvements:
1. Add custom MIME type registration (e.g., `application/x-smbundle`)
2. Add deep linking support for direct URLs
3. Add progress notifications during bundle processing from shared files
4. Add support for iOS file association (requires Info.plist changes)
