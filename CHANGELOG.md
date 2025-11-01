# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- No unreleased changes yet.

## [1.1.0] - 2025-11-01

### Added
- Android File Association for .smbundle files
  - Intent filters for VIEW action (opening from file managers)
  - Intent filters for SEND action (sharing from other apps)
  - Automatic bundle processing when files are opened or shared
  - Support for opening .smbundle files from WhatsApp, email, and other apps
  - Seamless user experience with automatic file association
  - Error handling for shared file processing
  - Documentation: SMBUNDLE_FILE_ASSOCIATION.md and TESTING_FILE_ASSOCIATION.md

### Changed
- Refactored bundle import logic into reusable `_processBundle()` method
- Added `receive_sharing_intent` package for handling shared files
- Desktop: Renderer-side i18n system with data-i18n markers; added locales (system, en, es, fr, nl, af, de, pt, id, ru, hi, ar, zh, tpi)
- Desktop: Success messages now use a custom non-blocking modal overlay (foreground) with localized strings, replacing the blocking alert
- Mobile (Android): Configured intent-filters for VIEW, SEND, and SEND_MULTIPLE to open/share .smbundle files; MainActivity forwards onNewIntent to receive_sharing_intent

### Fixed
- Mobile (Flutter): More reliable fullscreen behavior
  - Auto-enter fullscreen on rotate now throttled to avoid rapid re-entry loops on bouncy rotations
  - On exiting fullscreen, allowed orientations now include portrait and landscape so future rotations can re-trigger fullscreen
  - Fullscreen button restored: enters fullscreen matching current orientation (portrait or landscape). Auto behavior still enters on landscape and exits on portrait; suppression prevents bounce.
  - New setting to allow landscape rotation outside fullscreen; default portrait-only preserved if disabled

## [1.0.0] - 2024-01-15

### Added

#### Core Features
- **Desktop Bundler Application** (Electron-based)
  - UI for creating media bundles
  - Device ID registration and authorization
  - Media file encryption with AES-256
  - Playback limit configuration
  - Bundle export with comprehensive README
  - Cross-platform support (Windows, macOS, Linux)

- **Mobile Application** (React Native for Android)
  - Device identification and binding
  - Secure encrypted media storage
  - Bundle import and validation
  - Media playback with built-in player
  - Automatic playback tracking and limit enforcement
  - Timer-based playback reset intervals
  - Offline-first architecture

- **Shared Library** (@scripture-media/shared)
  - AES encryption/decryption utilities
  - Bundle schema and validation
  - Playback tracking logic
  - Device key generation
  - Reusable across desktop and mobile

#### Security Features
- Device-specific encryption keys
- Hardware-based device binding
- Encrypted file storage
- Temporary file cleanup
- Playback limit enforcement
- Anti-export measures
- No network dependencies

#### Documentation
- Comprehensive README with project overview
- SETUP.md - Installation and setup guide
- USAGE.md - Detailed usage instructions
- ARCHITECTURE.md - Technical architecture documentation
- SECURITY.md - Security analysis and threat model
- CONTRIBUTING.md - Contribution guidelines
- QUICKSTART.md - Quick start guide
- TROUBLESHOOTING.md - Common issues and solutions
- Example bundle configuration files

### Technical Details

#### Desktop App
- Electron 25.x
- Vanilla JavaScript (no framework overhead)
- Crypto-js for encryption
- Node.js built-in modules
- IPC-based architecture

#### Mobile App
- React Native 0.72
- react-native-device-info for device identification
- react-native-fs for file system operations
- react-native-video for media playback
- AsyncStorage for local persistence
- Custom security modules

#### Build System
- npm workspaces for monorepo structure
- Independent package management
- Shared dependencies via local package references
- Platform-specific build scripts

### Known Limitations

- Mobile app currently Android-only
- Manual bundle import process (UI pending)
- No iOS support yet
- Root access can bypass security measures
- Screen recording cannot be prevented
- Time manipulation affects reset intervals
- No remote revocation capability

### Future Enhancements

Planned for future releases:
- Bundle import UI in mobile app
- iOS support
- Root detection
- Screen recording detection
- Watermarking
- Code obfuscation
- Hardware security module integration
- Remote bundle revocation
- Analytics (privacy-preserving)

## Release Notes

### What's Working
✅ Desktop bundler creates encrypted bundles
✅ Mobile app displays device ID
✅ Device authorization validation
✅ Media encryption/decryption
✅ Playback tracking and limits
✅ Offline functionality
✅ Cross-platform desktop builds

### What Needs Implementation
⚠️ Mobile bundle import UI
⚠️ iOS mobile app
⚠️ Root detection
⚠️ Advanced security features
⚠️ Automated testing

### Breaking Changes
- N/A (initial release)

### Security Updates
- Initial security implementation
- AES-256 encryption
- Device binding
- See SECURITY.md for details

### Performance Improvements
- N/A (initial release)

### Bug Fixes
- N/A (initial release)

## Migration Guide

### From Nothing to 1.0.0
This is the initial release, so no migration needed. Follow SETUP.md and QUICKSTART.md to get started.

## Deprecations
None in this release.

## Contributors
- Initial implementation: Copilot
- Repository owner: rulingAnts

## Getting This Release

### Desktop App
```bash
git clone https://github.com/rulingAnts/scripture_media_trial_content_app.git
cd scripture_media_trial_content_app
npm install
npm run desktop
```

### Mobile App
```bash
cd mobile-app
npm install
npm run android
```

See SETUP.md for detailed installation instructions.

## Support

- Report issues on GitHub
- Read documentation for help
- Contact for security issues privately

---

## Version History

- **1.0.0** (2024-01-15) - Initial release

[1.0.0]: https://github.com/rulingAnts/scripture_media_trial_content_app/releases/tag/v1.0.0
