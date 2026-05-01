# Roadmap & Future Features

This document outlines planned enhancements and future development priorities.

## High Priority

### iOS Support
- Port mobile app to iOS
- iOS-specific device identification
- iOS secure storage implementation
- Testing on iOS devices
- Xcode project configuration

### Security Enhancements
- Root detection and warning system
- Code obfuscation for mobile app
- Tamper detection for APK modifications
- Hardware security module integration
- Screen recording detection (limited on Android)

### Device Owner / Kiosk Lockdown (Planned — Not Started)
For work-owned devices where the app should be the only thing the user can do with it. Should be offered as two separate build flavors: **managed** (device owner lockdown enabled) and **unmanaged** (standard behavior, current default).

**Managed version capabilities:**
- Prevent app uninstall
- Prevent factory reset
- Block other workarounds (re-enabling developer options, sideloading, etc.)
- Lock down Settings to prevent tampering
- Silently install/uninstall other apps
- Disable screen capture (where possible)

**Implementation:**
- Add `DeviceAdminReceiver` Kotlin class to `android/app/src/main/kotlin/`
- Add device admin policy XML (`res/xml/device_admin.xml`)
- Register receiver in `AndroidManifest.xml`
- Use Flutter build flavors to produce two APK variants: `managed` and `unmanaged`
- One-time ADB setup per device (part of the USB device integration workflow): `adb shell dpm set-device-owner com.yourpackage/.DeviceAdminReceiver`
- Device Owner setup must happen after factory reset, before any Google accounts are added
- Ties into the USB device integration workflow (TODO above) — managed device setup becomes an optional step in the one-click device loading process

### Testing Infrastructure
- Unit tests for encryption utilities
- Integration tests for bundle workflows
- Automated security testing
- Cross-device compatibility testing

## Desktop App: USB Device Integration (Planned — Not Started)

The goal of this feature set is to make loading Android devices with the Scripture app and content bundle as seamless as loading a Kulumi or Megavoice player — a single, simple GUI that walks a non-technical user through the entire process end-to-end.

### 1. Auto-detect Android Device ID via USB
- Detect attached Android devices (physical or AVD) from within the Electron desktop app when USB debugging is enabled
- Retrieve the Android ID (the same ID the mobile app uses for device binding) without requiring the user to find it manually
- Determine feasibility of bundling a minimal ADB binary with the Electron app vs. auto-downloading/installing the Android SDK/platform-tools from Google if ADB is not present
- Prefer bundling a minimal, pre-built ADB binary for the target platform (Windows/macOS/Linux) to avoid requiring Android Studio installation
- If bundling is not feasible, implement auto-download and silent install of Android platform-tools from Google's official CDN

### 2. Auto-install the Mobile App on Attached Device
- Detect whether the Scripture Media app (com.scripture.media or equivalent package name) is installed on the attached device
- Detect whether an older version is installed (compare version codes)
- If not installed or outdated, automatically install the APK bundled with or alongside the desktop app
- No advanced technical knowledge should be required from the user
- Bundle a current release APK with the desktop app distribution (or provide a mechanism to download it)

### 3. Auto-load Bundle onto Attached Device
- After the bundle is created (or when an existing bundle is selected), automatically push it to the attached Android device via ADB
- Trigger the mobile app to open/import the bundle automatically (via ADB intent or file association)
- Detect the correct storage location on the device for file delivery

### 4. End-to-End "One-Click" Device Loading Workflow
- Combine features 1–3 into a unified, guided workflow in the desktop app GUI
- Single flow: plug in device → app detects it → retrieves device ID → pre-populates it in the bundle config → creates bundle → installs app if needed → pushes bundle → confirms success
- Include clear in-app instructions for enabling USB debugging (with screenshots or step-by-step text) and reminding the user to disable it afterward
- Handle common failure cases gracefully: device not recognized, USB debugging off, authorization prompt pending on device, multiple devices attached
- Design for non-technical content creators (SIL/Bible translation workers) — no terminal or ADB knowledge required

## Medium Priority

### Playback Limits: Advanced Features

Refer to `docs/archive/ADVANCED_PLAYBACK_LIMITS.md` and `docs/archive/PLAYLIST_LIMITS.md` for detailed specifications. Summary:

- **Geofencing**: Reset or grant extra plays based on location changes
- **Per-media granular overrides**: More fine-grained control per file
- **Enhanced cooldown options**: More flexible interval configurations
- **Better expiration handling**: More sophisticated expiration rules

### User Experience
- Progress indicators for bundle creation and import
- Better error messages with suggested solutions
- Localization for more languages (currently supports 12 languages in desktop app)
- In-app help and tutorials

### Content Management
- Desktop app ability to open and edit existing .smbundle files
- Batch operations for multiple bundles
- Bundle templates for common configurations
- Bundle versioning and update mechanism

### Free/Shareable Bundled Media (Planned — Not Started)
Media that is freely shareable (no device binding, no playback limits) but bundled into the app itself so it cannot be easily deleted accidentally or intentionally. Distributable phone-to-phone via WiFi without any internet connection.

- Free media embedded as app assets (part of the APK) rather than imported bundles — not deletable by the user
- Alternatively, stored in protected app-internal storage and restored automatically if deleted
- WiFi-based phone-to-phone sharing (WiFi Direct or local hotspot) — no internet required, no cables
- Recipient phone does not need the app pre-installed (or app installation is part of the transfer)
- Separate from the restricted trial content system — these files have no encryption or playback limits
- Desktop app should have a way to designate media as "free" vs "restricted trial" when building

## Low Priority

### Analytics & Monitoring
- Privacy-preserving usage analytics (opt-in)
- Bundle distribution tracking
- Performance monitoring
- Error reporting (opt-in)

### Advanced Features
- Watermarking for traceability
- Remote bundle revocation capability
- Multi-device bundles with different keys per device
- Server-side validation option (for online scenarios)
- Compressed/optimized media encoding

### Developer Tools
- Bundle validation tools
- Device ID management utilities
- Automated testing suite
- CI/CD pipeline improvements

## Completed Features

✅ File association for .smbundle files on Android  
✅ Multilingual desktop app interface  
✅ Comprehensive playback limits (windowed, interval, total, expiration)  
✅ Playlist-level limits  
✅ Time tampering detection  
✅ Fullscreen video playback with rotation handling  
✅ Bundle encryption and integrity verification  

## Contributing

Contributions are welcome! See [COMMUNITY.md](COMMUNITY.md) for guidelines.

Particularly helpful contributions:
- iOS support implementation
- Security improvements
- Automated testing
- Documentation improvements
- Bug fixes

## Status Key

- ✅ Completed
- 🚧 In Progress
- 📋 Planned
- 💡 Proposed

## Notes

This roadmap is subject to change based on:
- User feedback and feature requests
- Security considerations
- Technical feasibility
- Contributor availability
- Project priorities

For implementation details of specific features, see documentation in `docs/archive/`.

- [ ] Unit tests for admission logic (happy path + cooldown + lifetime cap + expiry)
- [ ] Integration tests for import → enforce → UI messages
- [ ] Backward compatibility tests with legacy bundles

## Documentation
- [ ] Update `README.md`/`USAGE.md` with new fields and examples
- [ ] Update `desktop-app/README.md` authoring guide and screenshots
