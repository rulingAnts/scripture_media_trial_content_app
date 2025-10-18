# Architecture Documentation

## System Overview

The Scripture Media Trial Content App is designed as a secure, device-restricted media distribution system consisting of three main components:

1. **Shared Library** - Common utilities and business logic
2. **Desktop Bundler App** - Content creation and encryption tool
3. **Mobile App** - Android player with security restrictions

## Design Principles

### Security First
- All media content is encrypted at rest
- Device-specific encryption keys prevent unauthorized access
- No network requirements reduce attack surface
- Playback tracking cannot be bypassed

### Offline-First
- All functionality works without internet
- Local storage for all data
- No cloud dependencies

### Simple Distribution
- Bundles are portable folders
- Easy to share via any file transfer method
- No server infrastructure required

## Component Architecture

### 1. Shared Library (`@scripture-media/shared`)

Located in `/shared/`, this library contains code shared between desktop and mobile apps.

#### Modules

**encryption.js**
- AES encryption/decryption of media files
- Device key generation using SHA-256
- Uses crypto-js library

```javascript
encrypt(data, key) → encryptedData
decrypt(encryptedData, key) → originalData
generateDeviceKey(deviceId, salt) → deviceKey
```

**bundle-schema.js**
- Bundle configuration structure
- Validation logic
- Schema:
  ```json
  {
    "version": "1.0",
    "bundleId": "unique-id",
    "createdAt": "ISO-8601 timestamp",
    "allowedDeviceIds": ["device-id-1", "device-id-2"],
    "mediaFiles": [
      {
        "id": "uuid",
        "fileName": "original-name.mp3",
        "title": "Display Title",
        "type": "audio|video",
        "encryptedPath": "media/uuid.enc",
        "checksum": "sha256-hash",
        "playbackLimit": {
          "maxPlays": 3,
          "resetIntervalHours": 24
        }
      }
    ],
    "playbackLimits": {
      "default": {
        "maxPlays": 3,
        "resetIntervalHours": 24
      }
    }
  }
  ```

**playback-tracker.js**
- Tracks playback events
- Enforces playback limits
- Manages reset intervals
- Storage-agnostic design (works with any key-value store)

```javascript
class PlaybackTracker {
  recordPlayback(mediaId) → history
  canPlay(mediaId, limits) → { canPlay, remainingPlays, nextResetTime }
  cleanupOldRecords(mediaId, resetIntervalHours) → history
}
```

### 2. Desktop Bundler App

Electron-based desktop application for creating bundles.

#### Technology Stack
- Electron 25.x
- Vanilla JavaScript (no framework)
- Node.js built-in modules
- crypto-js for encryption

#### Architecture

```
desktop-app/
├── src/
│   ├── main.js         # Electron main process
│   ├── renderer.js     # UI logic
│   └── index.html      # User interface
└── package.json
```

**Main Process (main.js)**
- Window management
- File system operations
- IPC handlers for:
  - File selection dialogs
  - Bundle creation
  - Media encryption
  - Directory operations

**Renderer Process (renderer.js)**
- User interface logic
- Form validation
- Media file management
- Bundle configuration

#### Bundle Creation Flow

1. User configures bundle parameters
2. User selects media files
3. User selects output directory
4. For each media file:
   - Generate unique media ID (UUID)
   - Read file into memory
   - Convert to Base64
   - Encrypt with device key
   - Write encrypted file to bundle
   - Calculate checksum
5. Create bundle configuration (bundle.json)
6. Write README with instructions
7. Return bundle location to user

#### Security Considerations

- Media files are encrypted using first device ID as base key
- All authorized devices must share the same encryption key
- Original files are never stored unencrypted in bundles
- Checksums verify file integrity

### 3. Mobile App

React Native application for Android devices.

#### Technology Stack
- React Native 0.72
- react-native-device-info for device identification
- react-native-fs for file system access
- react-native-video for media playback
- AsyncStorage for local data persistence

#### Architecture

```
mobile-app/
├── src/
│   ├── DeviceBinding.js    # Device identification
│   ├── SecureStorage.js    # Encrypted file management
│   ├── BundleManager.js    # Bundle loading and validation
│   └── MediaPlayer.js      # Playback with limits
├── App.js                  # Main UI component
└── package.json
```

#### Modules

**DeviceBinding.js**
- Retrieves unique device identifier
- Generates device-specific encryption key
- Verifies device authorization

```javascript
initialize() → { deviceId, deviceKey, brand, model }
isDeviceAllowed(allowedDeviceIds) → boolean
getDeviceId() → deviceId
getDeviceKey() → deviceKey
```

**SecureStorage.js**
- Manages encrypted file storage
- Creates secure storage directory
- Handles encryption/decryption
- Cleans up temporary files

```javascript
storeMediaFile(mediaId, encryptedData) → filePath
retrieveMediaFile(mediaId) → tempPath
clearTempFiles()
mediaFileExists(mediaId) → boolean
deleteMediaFile(mediaId)
```

**BundleManager.js**
- Loads and validates bundles
- Manages current bundle state
- Imports media files into secure storage

```javascript
loadBundle(bundlePath) → bundle
getCurrentBundle() → bundle
getMediaFiles() → mediaFiles[]
importMediaFiles(bundleDir) → importedCount
clearBundle()
```

**MediaPlayer.js**
- Coordinates playback
- Enforces playback limits
- Tracks usage statistics
- Manages temporary decrypted files

```javascript
prepareMedia(mediaId) → { canPlay, mediaPath, remainingPlays }
startPlayback(mediaId)
cleanupPlayback()
getPlaybackStats(mediaId) → stats
```

#### Data Flow

**Loading a Bundle:**
```
User selects bundle
  ↓
BundleManager.loadBundle(path)
  ↓
Read bundle.json
  ↓
Validate structure
  ↓
Check device authorization
  ↓
Store configuration in AsyncStorage
  ↓
Import encrypted media files
  ↓
Copy to SecureStorage
  ↓
Display media list
```

**Playing Media:**
```
User taps Play
  ↓
MediaPlayer.prepareMedia(mediaId)
  ↓
Get media file config
  ↓
Check playback limits (PlaybackTracker)
  ↓
If allowed:
  ├─ SecureStorage.retrieveMediaFile(mediaId)
  ├─ Decrypt to temp location
  ├─ MediaPlayer.startPlayback(mediaId)
  ├─ Record playback event
  └─ Play in Video component
  ↓
On stop/end:
  └─ MediaPlayer.cleanupPlayback()
      └─ Delete temp files
```

#### Security Features

1. **Device Binding**
   - Uses device hardware ID (cannot be changed)
   - Verified on every bundle load
   - Prevents unauthorized devices

2. **Encrypted Storage**
   - Media files stored encrypted on disk
   - Encryption key derived from device ID
   - Cannot be accessed outside app

3. **Playback Tracking**
   - Play counts stored in AsyncStorage
   - Persists across app restarts
   - Cannot be easily reset

4. **Temporary Decryption**
   - Files decrypted to cache directory
   - Only during active playback
   - Automatically cleaned up

5. **Anti-Export**
   - No UI for sharing or exporting
   - No access to decrypted files
   - No screenshot capability on secure content

## Security Analysis

### Threat Model

**Threats Considered:**
1. Unauthorized device access
2. Content extraction/copying
3. Playback limit bypass
4. Content sharing via APK
5. Bundle redistribution

**Mitigations:**

| Threat | Mitigation | Effectiveness |
|--------|-----------|---------------|
| Unauthorized device | Device ID whitelist | High - hardware-based |
| Content extraction | Encryption at rest | High - requires device key |
| Limit bypass | Local tracking with timestamps | Medium - can be reset with root |
| APK sharing | Device-specific keys | High - content won't decrypt |
| Bundle redistribution | Device authorization check | High - authorized devices only |

### Known Limitations

1. **Root Access**: Rooted devices can potentially:
   - Access encrypted files
   - Modify playback tracking
   - Extract encryption keys from memory
   
2. **Screen Recording**: Cannot prevent:
   - Screen recording during playback
   - Audio recording with another device

3. **Device ID Changes**: Rare scenarios:
   - Factory reset might change device ID
   - Custom ROMs might affect device identification

4. **Time Manipulation**: 
   - User could change system time
   - Affects playback reset intervals
   - Mitigation: Use monotonic clock (future enhancement)

### Best Practices for Deployment

1. **Device ID Collection**
   - Collect device IDs through secure channels
   - Verify device ownership before authorization
   - Keep device ID registry secure

2. **Bundle Distribution**
   - Use secure channels (encrypted email, private links)
   - Don't publish bundles publicly
   - Version bundles for tracking

3. **Playback Limits**
   - Set reasonable limits for intended use
   - Consider review timeline when setting reset intervals
   - Document limits clearly

4. **Content Protection**
   - Use in conjunction with legal agreements
   - Don't rely solely on technical measures
   - Educate users on proper use

## Performance Considerations

### Desktop App
- **Memory**: Loads entire media files into memory for encryption
- **Disk**: Requires 2x source media size (original + encrypted)
- **CPU**: AES encryption is CPU-intensive for large files
- **Optimization**: Process files sequentially to manage memory

### Mobile App
- **Storage**: Encrypted files are similar size to originals
- **Memory**: Decrypts to memory before writing to cache
- **CPU**: Decryption happens once per playback
- **Battery**: Video playback is battery-intensive
- **Optimization**: Clean up temp files promptly

## Future Enhancements

### Planned Features
1. **Import UI**: Add bundle import flow in mobile app
2. **Progress Indicators**: Show encryption/decryption progress
3. **Batch Operations**: Handle multiple bundles
4. **Analytics**: Track bundle usage (with privacy)
5. **Remote Revocation**: Ability to disable bundles remotely
6. **Watermarking**: Add identifying information to playback

### Technical Improvements
1. **Streaming Decryption**: Avoid full file decryption
2. **Hardware Security**: Use Android Keystore
3. **Tamper Detection**: Detect modified APKs
4. **Time Validation**: Use NTP for reliable time
5. **Multi-device Bundles**: Different keys per device

## Testing Strategy

### Unit Tests
- Encryption/decryption functions
- Bundle schema validation
- Playback tracking logic

### Integration Tests
- Bundle creation end-to-end
- Media import and playback
- Device authorization flow

### Manual Testing
- Desktop app UI flows
- Mobile app user experience
- Cross-device compatibility
- Bundle portability

### Security Testing
- Encrypted file inspection
- Device ID spoofing attempts
- Playback limit bypass attempts
- Bundle sharing scenarios

## Deployment

### Desktop App Distribution
- Build for Windows, macOS, Linux
- Sign executables for security
- Provide installation instructions
- Consider auto-updates

### Mobile App Distribution
- Build signed APK
- Distribute via:
  - Direct download
  - Private app store
  - Enterprise distribution
- Don't publish to Google Play (device restriction limitations)

### Documentation
- Setup guides for developers
- User manuals for both apps
- Troubleshooting guides
- Security advisories

## Maintenance

### Version Management
- Semantic versioning for all components
- Maintain compatibility matrix
- Document breaking changes
- Provide migration guides

### Monitoring
- Error reporting (opt-in)
- Usage metrics (privacy-preserving)
- Performance monitoring
- Security incident response

### Support
- Issue tracking
- User support channels
- Developer documentation
- Security contact
