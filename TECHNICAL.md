# Technical Documentation

Architecture, security, and implementation details for the Scripture Media Trial Content App.

## Table of Contents

- [System Overview](#system-overview)
- [Architecture](#architecture)
- [Security](#security)
- [Technology Stack](#technology-stack)
- [Implementation Details](#implementation-details)
- [Performance](#performance)

## System Overview

The Scripture Media Trial Content App is a secure, device-restricted media distribution system with three main components:

1. **Shared Library** - Common utilities and business logic
2. **Desktop Bundler App** - Content creation and encryption tool (Electron)
3. **Mobile App** - Android player with security restrictions (Flutter)

### Design Principles

**Security First**:
- All media encrypted at rest
- Device-specific encryption keys
- No network requirements reduce attack surface
- Playback tracking cannot be easily bypassed

**Offline-First**:
- All functionality works without internet
- Local storage for all data
- No cloud dependencies

**Simple Distribution**:
- Bundles are portable `.smbundle` files
- Easy to share via any file transfer method
- No server infrastructure required

## Architecture

### Component Structure

```
scripture_media_trial_content_app/
├── shared/                 # Shared utilities (JavaScript)
│   ├── src/
│   │   ├── encryption.js        # AES encryption via CryptoJS
│   │   ├── bundle-schema.js     # Bundle configuration schema
│   │   ├── playback-tracker.js  # Playback limit tracking
│   │   └── index.js
│   └── package.json
├── desktop-app/           # Electron desktop bundler
│   ├── src/
│   │   ├── main.js              # Electron main process
│   │   ├── renderer.js          # UI logic
│   │   └── index.html           # User interface
│   └── package.json
├── mobile_app/            # Flutter Android app
│   ├── lib/
│   │   └── main.dart            # Main application logic
│   ├── android/                 # Android configuration
│   └── pubspec.yaml
└── scripts/               # Build and utility scripts
```

### Shared Library (`shared/`)

#### encryption.js

Provides CryptoJS-based helpers used for configuration encryption and key wrapping:
```
encrypt(data, key) → encryptedData           // OpenSSL-compatible output
decrypt(encryptedData, key) → originalData   // Accepts OpenSSL salted input
generateDeviceKey(deviceId, salt) → deviceKey
```

- AES (CryptoJS) for configuration and key wrapping
- SHA-256 for device key derivation
- Per-device wrapped bundle key (v2.1+) prevents unauthorized access
- Device-specific keys prevent unauthorized access

#### bundle-schema.js

Defines bundle configuration structure:

```json
{
  "version": "2.0",
  "bundleId": "unique-id",
  "createdAt": "ISO-8601 timestamp",
  "allowedDeviceIds": ["device-id-1", "device-id-2"],
  "expirationDate": "ISO-8601 timestamp",
  "playlistLimits": {
    "maxItemsPerSession": 3,
    "sessionResetIntervalMs": 86400000,
    "minIntervalBetweenItemsMs": 600000,
    "maxTotalItemsPlayed": 15,
    "expirationDate": "ISO-8601 timestamp"
  },
  "playbackLimits": {
    "default": {
      "maxPlays": 3,
      "resetIntervalMs": 86400000,
      "minIntervalBetweenPlaysMs": 300000,
      "maxPlaysTotal": 10
    }
  },
  "mediaFiles": [
    {
      "id": "uuid",
      "fileName": "original-name.mp3",
      "title": "Display Title",
      "type": "audio|video",
      "encryptedPath": "media/uuid.enc",
      "checksum": "sha256-hash"
    }
  ]
}
```

#### playback-tracker.js

Tracks playback events and enforces limits:

```javascript
class PlaybackTracker {
  recordPlayback(mediaId) → history
  canPlay(mediaId, limits) → { canPlay, remainingPlays, nextResetTime }
  cleanupOldRecords(mediaId, resetIntervalMs) → history
}
```

### Desktop Bundler App (Electron)

#### Technology Stack
- Electron 25.x
- Vanilla JavaScript (no framework)
- Node.js built-in modules
- CryptoJS for encryption

#### Main Process (main.js)

Handles:
- Window management
- File system operations
- IPC handlers for:
  - File selection dialogs
  - Bundle creation
  - Media encryption
  - Directory operations

#### Renderer Process (renderer.js)

Handles:
- User interface logic
- Form validation
- Media file management
- Bundle configuration
- Multi-language support (i18n)

#### Bundle Creation Flow

1. User configures bundle parameters
2. User selects media files
3. User selects output directory
4. Generate a random per-bundle content key (32 bytes)
5. For each media file (streaming, no full file in memory):
  - Generate unique media ID (UUID)
  - Stream original bytes, compute SHA-256 checksum
  - Apply lightweight xor-v1 obfuscation using the bundle key + per-file salt
  - Write `.obf` output to `media/`
6. For each authorized device ID, derive a wrapping key via SHA-256(deviceId + salt) and encrypt (wrap) the bundle key
7. Create bundle configuration (includes: media entries, integrity, per-device wrapped keys)
8. Encrypt the bundle configuration with a shared config key
9. Package as `.smbundle` (tar.gz archive)
10. Return bundle location to user

### Mobile App (Flutter)

#### Technology Stack
- Flutter SDK 3.9.2+
- Dart language
- Android platform (iOS support planned)
- `encrypt` package for AES encryption
- `crypto` package for hashing
- `pointycastle` for cryptographic primitives

#### Key Modules

**Device Binding**:
- Retrieves unique device identifier (Android ID)
- Generates device-specific encryption key
- Verifies device authorization

**Secure Storage**:
- Manages encrypted file storage
- Creates secure storage directory
- Handles encryption/decryption
- Cleans up temporary files

**Bundle Management**:
- Loads and validates bundles
- Manages current bundle state
- Imports media files into secure storage
- Handles `.smbundle` file association

**Media Player**:
- Coordinates playback
- Enforces playback limits
- Tracks usage statistics
- Manages temporary decrypted files

#### Data Flow

**Loading a Bundle**:
```
User taps .smbundle file
  ↓
File association triggers app
  ↓
Extract tar.gz archive
  ↓
Read encrypted bundle config
  ↓
Decrypt config with device key
  ↓
Validate structure and device authorization
  ↓
Import encrypted media files
  ↓
Store in app private directory
  ↓
Display media list
```

**Playing Media**:
```
User taps Play
  ↓
Check time tampering
  ↓
Check bundle expiration
  ↓
Check playlist limits
  ↓
Check per-file limits
  ↓
If allowed:
  ├─ Decrypt media to temp location
  ├─ Start playback
  ├─ Record playback event
  └─ Update tracking data
  ↓
On stop/end:
  └─ Delete temp files
```

## Security

### Security Goals

1. **Device Restriction**: Content only accessible on authorized devices
2. **Content Protection**: Media files cannot be extracted or shared
3. **Usage Control**: Enforce playback limits per content policy
4. **Offline Security**: No network dependencies that could be exploited
5. **Portability Prevention**: Content bound to specific hardware

### Security Architecture

#### 1. Device Binding

**Mechanism**:
- Each Android device has unique hardware identifier (Android ID)
- Retrieved using platform-specific APIs
- Cannot be changed without hardware modification or factory reset

**Implementation**:
```dart
final deviceId = await getAndroidId();
```

**Security Properties**:
- Persists across app reinstalls
- Persists across OS updates
- Changes on factory reset (acceptable tradeoff)
- Difficult to spoof without root access

**Threats Mitigated**:
- Unauthorized device access
- APK sharing (won't work on other devices)
- Content redistribution

**Residual Risks**:
- Root access can potentially spoof device ID
- Device cloning (extremely rare)

#### 2. Content Protection

**Mechanisms**:
- Media: xor-v1 streaming obfuscation keyed by a random per-bundle content key + per-file salt (current default)
- Legacy support: AES-256-CBC with OpenSSL salted header (CryptoJS-compatible) for media encrypted in older bundles
- Configuration: encrypted with a shared config key (CryptoJS)
- Key management: per-device wrapping of the bundle content key using a SHA-256(deviceId + salt)-derived key

**Desktop (key wrapping)**:
```javascript
const deviceKey = generateDeviceKey(deviceId, salt);
const wrappedBundleKey = encrypt(bundleKey, deviceKey);
```

**Mobile (unwrapping + media decode)**:
```dart
final deviceKey = generateDeviceKey(androidId, salt);
final bundleKey = decryptWrappedKey(wrapped, deviceKey); // CryptoJS/OpenSSL format
// xor-v1: stream deobfuscation using bundleKey + per-file salt
// legacy: stream AES-256-CBC decryption (OpenSSL salted header)
```

**Key Properties**:
- Bundle key never stored on disk, only unwrapped in memory
- Per-device wrapped keys inside the bundle (same bundle for all authorized devices)
- 256-bit key material for CryptoJS AES operations

**Threats Mitigated**:
- File extraction from storage (non-playable without unwrapping)
- Bundle copying to unauthorized devices
- Tampering (integrity checks)

**Residual Risks**:
- Memory extraction while content is in use (requires root/debugger)
- xor-v1 is obfuscation (not cryptographically strong) but gated by device-bound key unwrapping

#### 3. Secure Storage

**Mechanism**:
- Encrypted files stored in app's private directory
- Decrypted files only in temporary cache
- Automatic cleanup after playback

**Storage Locations** (Android):
```
Encrypted: /data/data/net.iraobi.scripturedemoplayer/files/
Temporary: /data/data/net.iraobi.scripturedemoplayer/cache/
```

**Security Properties**:
- Private app directory (protected by Android)
- Not accessible to other apps
- Cleared on app uninstall
- Cache cleaned automatically

**Threats Mitigated**:
- File browser access
- Cross-app data access
- Backup/restore extraction

**Residual Risks**:
- Root access bypasses directory protection
- Physical device access with ADB (if debugging enabled)
- Android backup if not disabled

#### 4. Playback Tracking

**Mechanism**:
- Play counts stored in SharedPreferences
- Timestamp-based limit enforcement
- Reset intervals calculated from first play in period

**Data Structure**:
```json
{
  "playback_mediaId": {
    "plays": ["2024-01-01T10:00:00Z", "2024-01-01T15:00:00Z"],
    "playsTotal": 2,
    "lastPlay": "2024-01-01T15:00:00Z"
  }
}
```

**Security Properties**:
- Persists across app restarts
- Timestamps include date and time
- Old records cleaned up automatically

**Threats Mitigated**:
- Unlimited playback
- Policy violation
- Resource abuse

**Residual Risks**:
- App data clearing resets counts
- Time manipulation (system clock change)
- Root access to storage

#### 5. Time Tampering Detection

**Mechanism**:
- Track last known system time
- Compare on each app launch
- If current time < last known time, permanent lock

**Implementation**:
```dart
final lastKnownTime = await getLastKnownTime();
final currentTime = DateTime.now();
if (currentTime.isBefore(lastKnownTime)) {
  // Tampering detected - permanent lock
  lockBundle();
}
updateLastKnownTime(currentTime);
```

**Threats Mitigated**:
- Bypassing expiration dates
- Resetting playback limits
- Time-based limit circumvention

**Limitations**:
- Cannot prevent all time manipulation
- Relies on system clock
- NTP validation would require network

#### 6. Bundle Integrity

**Mechanism**:
- SHA-256 checksums for all media files
- Encrypted bundle configuration
- Tamper-evident archive format

**Threats Mitigated**:
- Bundle modification
- Media file substitution
- Configuration tampering

### Threat Analysis

#### High Priority Threats

**T1: Unauthorized Device Access**
- Attack: Copying bundle to unauthorized device
- Mitigation: ✅ Device ID whitelist, device-specific encryption
- Status: Well mitigated

**T2: Content Extraction**
- Attack: Extract media files from app
- Mitigation: ✅ AES encryption, private directory, temp file cleanup
- Status: Well mitigated (except with root)

**T3: Playback Limit Bypass**
- Attack: Exceed playback limits
- Mitigation: ✅ Persistent tracking, ⚠️ time manipulation possible
- Status: Partially mitigated

#### Medium Priority Threats

**T4: APK Modification**
- Attack: Modify APK to bypass restrictions
- Mitigation: ⚠️ APK signing (basic), ❌ no tamper detection
- Status: Limited mitigation
- Recommendation: Add tamper detection and code obfuscation

**T5: Screen Recording**
- Attack: Record screen during playback
- Mitigation: ❌ No prevention possible on Android
- Status: Not mitigated
- Note: Consider watermarking for traceability

**T6: Bundle Sharing**
- Attack: Authorized user shares bundle
- Mitigation: ✅ Device ID restriction, ⚠️ social/legal deterrents
- Status: Technical mitigation limited

#### Low Priority Threats

**T7: Memory Analysis**
- Attack: Extract keys/content from memory
- Mitigation: ⚠️ Keys derived not stored, ❌ no memory protection
- Status: Limited mitigation
- Note: Requires root/debugger access

### Security Best Practices

**For Deployment**:
1. Collect device IDs through secure channels
2. Verify device ownership before authorization
3. Use secure bundle distribution (HTTPS, encrypted email)
4. Sign APK with secure keystore
5. Rotate keys periodically

**For Users**:
1. Keep device screen locked
2. Don't root the device
3. Install from trusted sources only
4. Keep Android OS updated
5. Don't share device ID or bundles

### Known Limitations

1. **Root Access**: Rooted devices can bypass most protections
   - Impact: High
   - Mitigation: Detect root and warn/block (not implemented)

2. **Time Manipulation**: User can change system time
   - Impact: Medium
   - Mitigation: Use monotonic clock or NTP (not implemented)

3. **Screen Recording**: Cannot prevent screen recording
   - Impact: Medium
   - Mitigation: Watermarking, screen recording detection (not implemented)

4. **Social Engineering**: User could share authorized device
   - Impact: Low to Medium
   - Mitigation: User education, monitoring (policy-based only)

## Technology Stack

### Desktop App
- **Platform**: Electron 25.x
- **Language**: JavaScript (ES6+)
- **UI**: HTML5, CSS3, vanilla JavaScript
- **Encryption**: CryptoJS (AES-256, SHA-256)
- **Build**: electron-builder

### Mobile App
- **Platform**: Flutter SDK 3.9.2+
- **Language**: Dart
- **Target**: Android (iOS planned)
- **Encryption**: `encrypt` package (AES-256), `crypto` (SHA-256), `pointycastle`
- **Media**: `video_player`, `audio_session`
- **Storage**: `shared_preferences`, `path_provider`
- **File Handling**: `file_picker`, `archive`, `receive_sharing_intent`

### Shared Library
- **Language**: JavaScript (Node.js)
- **Encryption**: CryptoJS
- **Validation**: Custom schema validators

## Implementation Details

### Encryption Workflow

**Bundle Creation (Desktop)**:
1. User selects media files
2. Generate unique bundle ID and media IDs
3. Derive encryption key from first device ID
4. For each media file:
   - Read file content
   - Encrypt with AES-256
   - Calculate SHA-256 checksum
   - Store encrypted file
5. Create bundle configuration
6. Encrypt configuration
7. Package as `.smbundle` (tar.gz)

**Bundle Import (Mobile)**:
1. Receive `.smbundle` file
2. Extract tar.gz archive
3. Read encrypted bundle config
4. Derive decryption key from device ID
5. Decrypt configuration
6. Validate device authorization
7. Import encrypted media files
8. Store in app private directory

**Media Playback (Mobile)**:
1. User selects media
2. Check all playback limits
3. If allowed:
   - Read encrypted media from storage
   - Decrypt using streaming AES decryptor
   - Write to temp cache
   - Play media
   - Record playback
4. On completion:
   - Delete temp file
   - Update tracking data

### File Formats

**`.smbundle` File Structure**:
```
bundle_name.smbundle (tar.gz archive)
├── bundle.smb (encrypted configuration)
└── media/
  ├── uuid1.ext.obf (obfuscated media file, xor-v1)
  ├── uuid2.ext.obf
  └── ...
```

**Bundle Configuration** (before encryption):
```json
{
  "version": "2.0",
  "bundleId": "uuid",
  "createdAt": "2024-01-15T12:00:00Z",
  "allowedDeviceIds": ["device1", "device2"],
  "expirationDate": "2025-12-31T23:59:59Z",
  "playlistLimits": { ... },
  "playbackLimits": { ... },
  "mediaFiles": [ ... ]
}
```

### Data Persistence (Mobile)

**SharedPreferences Keys**:
```
bundle:current                              → Current bundle ID
bundle:${bundleId}:config                   → Bundle configuration
playback:${mediaId}:plays                   → Play timestamps
playback:${mediaId}:total                   → Total plays
playback:${mediaId}:lastPlay                → Last play timestamp
playlistSession:${bundleId}:items           → Session items list
playlistSession:${bundleId}:start           → Session start time
playlistTotal:${bundleId}:items             → Total items played
playlistLastItemPlay:${bundleId}            → Last item play time
app:lastKnownTime                           → Last known system time
```

## Performance

### Desktop App
- **Memory**: Streams media during obfuscation (no full-file buffering)
- **Disk**: Requires ~1x source media size during processing (+temporary files)
- **CPU**: xor-v1 is lightweight; checksum computation is the main cost
- **Optimization**: Sequential streaming, per-file salt, integrity recorded

### Mobile App
- **Storage**: Encrypted files similar size to originals
- **Memory**: Streaming decryption minimizes memory usage
- **CPU**: Decryption optimized with native cryptographic libraries
- **Battery**: Video playback is battery-intensive
- **Optimization**: Temp files cleaned up promptly

### Optimization Strategies

1. **Streaming Decryption**: Large files decrypted in chunks
2. **Lazy Loading**: Media decrypted only when played
3. **Temp File Cleanup**: Automatic cleanup after playback
4. **Efficient Storage**: Compressed archive format
5. **Minimal UI**: Simple interface reduces overhead

## Future Enhancements

### Planned Features
- iOS support
- Root detection
- Screen recording detection
- Watermarking
- Hardware security module integration
- Remote bundle revocation
- Code obfuscation
- Advanced tamper detection

### Technical Improvements
- Streaming encryption/decryption
- Hardware-backed keystores
- NTP time validation
- Multi-device bundle support with different keys per device
- Automated testing suite
