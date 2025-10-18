# Security Documentation

## Overview

This document outlines the security measures implemented in the Scripture Media Trial Content App and provides guidance for secure deployment and usage.

## Security Goals

1. **Device Restriction**: Content only accessible on authorized devices
2. **Content Protection**: Media files cannot be extracted or shared
3. **Usage Control**: Enforce playback limits per content policy
4. **Offline Security**: No network dependencies that could be exploited
5. **Portability Prevention**: Content bound to specific hardware

## Security Architecture

### 1. Device Binding

**Mechanism:**
- Each Android device has a unique hardware identifier
- Retrieved using `react-native-device-info.getUniqueId()`
- Based on Android's `ANDROID_ID` or device serial number
- Cannot be changed without hardware modification

**Implementation:**
```javascript
const deviceId = await DeviceInfo.getUniqueId();
```

**Security Properties:**
- Persists across app reinstalls
- Persists across OS updates
- Changes on factory reset (acceptable tradeoff)
- Difficult to spoof without root access

**Threats Mitigated:**
- Unauthorized device access
- APK sharing (won't work on other devices)
- Content redistribution

**Residual Risks:**
- Root access can potentially spoof device ID
- Device cloning (extremely rare)

### 2. Content Encryption

**Mechanism:**
- AES-256 encryption for all media files
- Device-specific encryption keys
- Key derivation: SHA-256(deviceId + salt)

**Implementation:**
```javascript
// Encryption (Desktop)
const deviceKey = generateDeviceKey(deviceId, salt);
const encryptedData = encrypt(mediaData, deviceKey);

// Decryption (Mobile)
const deviceKey = await DeviceBinding.getDeviceKey();
const decryptedData = decrypt(encryptedData, deviceKey);
```

**Key Properties:**
- Keys never stored on disk
- Derived on-demand from device ID
- Different for each device
- 256-bit key strength

**Threats Mitigated:**
- File extraction from storage
- Bundle copying to unauthorized devices
- Network interception (if bundles transmitted over network)

**Residual Risks:**
- Memory extraction while decrypted (requires root/debugger)
- Side-channel attacks (theoretical, low risk)

### 3. Secure Storage

**Mechanism:**
- Encrypted files stored in app's private directory
- Decrypted files only in temporary cache
- Automatic cleanup after playback

**Storage Locations:**
```
Encrypted: /data/data/com.scriptureMedia/files/secure_media/
Temporary: /data/data/com.scriptureMedia/cache/
```

**Security Properties:**
- Private app directory (protected by Android)
- Not accessible to other apps
- Cleared on app uninstall
- Cache cleaned automatically

**Threats Mitigated:**
- File browser access
- Cross-app data access
- Backup/restore extraction

**Residual Risks:**
- Root access bypasses directory protection
- Physical device access with ADB
- Android backup if not disabled

### 4. Playback Tracking

**Mechanism:**
- Play counts stored in AsyncStorage
- Timestamp-based limit enforcement
- Reset intervals calculated from first play in period

**Data Structure:**
```json
{
  "playback_mediaId": {
    "plays": ["2024-01-01T10:00:00Z", "2024-01-01T15:00:00Z"],
    "count": 2
  }
}
```

**Security Properties:**
- Persists across app restarts
- Timestamps include date and time
- Old records cleaned up automatically

**Threats Mitigated:**
- Unlimited playback
- Policy violation
- Resource abuse

**Residual Risks:**
- App data clearing resets counts
- Time manipulation (system clock change)
- Root access to storage

### 5. Anti-Export Measures

**Mechanisms:**
- No share/export functionality in UI
- No file access API exposed
- Temporary files in cache (auto-cleared)
- Video player doesn't support external paths

**Threats Mitigated:**
- Intentional content sharing
- Accidental content exposure
- Screen recording export

**Residual Risks:**
- Screen recording during playback
- Audio recording with external device
- Photography of screen

## Threat Analysis

### High Priority Threats

#### T1: Unauthorized Device Access
**Description:** Someone without an authorized device tries to access content.

**Attack Vectors:**
- Copying bundle to unauthorized device
- Sharing APK to unauthorized device
- Modifying bundle.json device list

**Mitigations:**
- ✅ Device ID whitelist in bundle
- ✅ Verification on bundle load
- ✅ Device-specific encryption keys

**Status:** Well mitigated

#### T2: Content Extraction
**Description:** User tries to extract media files from the app.

**Attack Vectors:**
- Accessing encrypted files
- Intercepting decryption
- Copying temporary files
- Using file managers

**Mitigations:**
- ✅ AES encryption at rest
- ✅ Private app directory
- ✅ Temporary file cleanup
- ✅ No export functionality

**Status:** Well mitigated (except with root)

#### T3: Playback Limit Bypass
**Description:** User tries to exceed playback limits.

**Attack Vectors:**
- Clearing app data
- Manipulating system time
- Reinstalling app
- Using multiple devices

**Mitigations:**
- ✅ Persistent playback tracking
- ✅ Timestamp validation
- ⚠️ Time manipulation possible
- ✅ Device-specific content

**Status:** Partially mitigated

### Medium Priority Threats

#### T4: APK Modification
**Description:** Attacker modifies APK to bypass restrictions.

**Attack Vectors:**
- Removing playback limits
- Disabling device checks
- Adding export functionality

**Mitigations:**
- ⚠️ APK signing (basic)
- ❌ No tamper detection
- ❌ No code obfuscation

**Status:** Limited mitigation

**Recommendation:** Add tamper detection and code obfuscation for production.

#### T5: Screen Recording
**Description:** User records screen during playback.

**Attack Vectors:**
- Built-in screen recorder
- Third-party recording apps
- External camera

**Mitigations:**
- ❌ No screen recording prevention
- ❌ No watermarking

**Status:** Not mitigated

**Note:** Complete prevention is not possible on Android. Consider watermarking for traceability.

#### T6: Bundle Sharing
**Description:** Authorized user shares bundle with others.

**Attack Vectors:**
- Copying bundle directory
- Uploading to cloud storage
- Sharing via messaging

**Mitigations:**
- ✅ Device ID restriction (limits usefulness)
- ⚠️ Social/legal deterrents only

**Status:** Technical mitigation limited

### Low Priority Threats

#### T7: Memory Analysis
**Description:** Attacker analyzes app memory to extract keys/content.

**Attack Vectors:**
- Memory dumps
- Debugger attachment
- Runtime hooking

**Mitigations:**
- ❌ No memory protection
- ❌ No anti-debugging
- ⚠️ Keys derived, not stored

**Status:** Limited mitigation

**Note:** Requires root/debugger access. Low risk for target audience.

## Security Best Practices

### For Deployment

1. **Device ID Management**
   - Collect device IDs through secure channels
   - Verify device ownership before authorization
   - Keep device ID database secure and private
   - Use encrypted communication for ID transmission

2. **Bundle Distribution**
   - Use secure channels (HTTPS, encrypted email)
   - Don't publish bundles on public websites
   - Use time-limited download links
   - Track bundle downloads

3. **APK Signing**
   - Sign APK with secure keystore
   - Keep signing keys in secure location
   - Use different keys for test/production
   - Rotate keys periodically

4. **User Communication**
   - Explain security features clearly
   - Set expectations about protection level
   - Provide contact for security issues
   - Document acceptable use policy

### For Users

1. **Device Security**
   - Keep device screen locked
   - Don't root the device
   - Install from trusted sources only
   - Keep Android OS updated

2. **Content Handling**
   - Don't share your device ID
   - Don't share bundles with others
   - Delete bundles when no longer needed
   - Report suspicious activity

3. **App Usage**
   - Don't screen record content
   - Don't modify the app
   - Don't clear app data unnecessarily
   - Follow content provider's policies

## Compliance Considerations

### Privacy

**Data Collected:**
- Device identifier (locally only)
- Playback timestamps (locally only)
- Media file checksums (for integrity)

**Data NOT Collected:**
- User identity
- Location
- Network activity
- Analytics

**Privacy Properties:**
- No network communication
- No cloud storage
- No third-party services
- User controls all data

### Copyright Protection

**Technical Measures:**
- Encryption (DMCA compliance)
- Access control (authorized devices only)
- Usage limits (playback restrictions)
- No export (prevents redistribution)

**Legal Measures:**
- Terms of use
- Copyright notices
- License agreements
- Acceptable use policy

**Note:** Technical measures alone are not sufficient. Combine with legal agreements.

## Security Limitations

### Known Weaknesses

1. **Root Access**
   - Rooted devices can bypass most protections
   - Can access encrypted files
   - Can modify playback tracking
   - Can extract encryption keys

   **Impact:** High
   **Mitigation:** Detect root and warn/block
   **Status:** Not implemented

2. **Time Manipulation**
   - User can change system time
   - Affects playback reset intervals
   - No network time validation

   **Impact:** Medium
   **Mitigation:** Use monotonic clock or NTP
   **Status:** Not implemented

3. **Screen Recording**
   - Cannot prevent screen recording
   - No watermarking for traceability
   - Content can be re-recorded

   **Impact:** Medium
   **Mitigation:** Watermarking, screen recording detection
   **Status:** Not implemented

4. **Social Engineering**
   - User could share their authorized device
   - Device ID could be obtained by attacker
   - Bundles could be shared (though unusable)

   **Impact:** Low to Medium
   **Mitigation:** User education, monitoring
   **Status:** Policy-based only

### By Design Limitations

1. **Offline Operation**
   - No remote revocation
   - No server-side validation
   - No real-time monitoring

   **Reason:** Requirement for offline functionality
   **Tradeoff:** Accepted for usability

2. **Local Storage**
   - All data stored on device
   - No cloud backup
   - Loss on factory reset

   **Reason:** Privacy and offline requirements
   **Tradeoff:** Accepted for security/privacy

3. **Single Platform**
   - Android only
   - Device-specific
   - No cross-device sync

   **Reason:** Security and platform constraints
   **Tradeoff:** Accepted for security

## Incident Response

### Security Issue Reporting

If you discover a security issue:

1. **Do NOT** disclose publicly
2. Contact: [security contact email]
3. Provide details:
   - Description of issue
   - Steps to reproduce
   - Impact assessment
   - Suggested fix (if any)

### Response Process

1. **Acknowledgment:** Within 48 hours
2. **Assessment:** Within 1 week
3. **Fix Development:** Priority based on severity
4. **Testing:** Thorough validation
5. **Release:** Coordinated disclosure
6. **Notification:** Inform affected users

### Severity Levels

- **Critical:** Remote code execution, bypass all security
- **High:** Content extraction, device restriction bypass
- **Medium:** Playback limit bypass, local data access
- **Low:** Information disclosure, minor issues

## Security Updates

### Versioning

Security-related changes follow semantic versioning:
- **Major:** Breaking security changes
- **Minor:** New security features
- **Patch:** Security fixes

### Update Recommendations

- **Critical/High:** Update immediately
- **Medium:** Update within 1 month
- **Low:** Update at convenience

### Update Channels

- GitHub releases
- Direct distribution
- Email notifications
- In-app update check (future)

## Conclusion

This application implements multiple layers of security to protect content and enforce usage policies. However, no security system is perfect. The measures implemented provide strong protection against common threats while maintaining usability for the intended use case.

**Key Strengths:**
- Device binding prevents unauthorized access
- Encryption protects content at rest
- Offline design reduces attack surface
- Simple architecture is easier to audit

**Key Weaknesses:**
- Root access bypasses most protections
- Screen recording cannot be prevented
- Time manipulation affects playback limits
- No remote control or revocation

**Recommendations:**
- Combine with legal agreements
- Educate users on proper use
- Monitor for suspicious patterns
- Update regularly
- Consider additional measures for high-value content

For high-security requirements, consider additional measures:
- Hardware security modules
- Server-side validation
- Watermarking
- Advanced tamper detection
- Professional security audit
