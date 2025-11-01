# Scripture Media Trial Content App

An app designed to allow specific people to share trial content (that doesn't yet have consultant approval) with a limited audience. This includes content locked up in the app, the app configured to be un-sharable, and limited number of plays per day (or hours) for each media item.

## Features

### Desktop Bundler App
- 🔒 **Secure Bundle Creation** - Encrypt media files with device-specific keys
- 📱 **Device Authorization** - Specify which devices can access content
- ⏱️ **Playback Limits** - Configure maximum plays and reset intervals
- 🎵 **Multi-format Support** - Audio and video files (MP3, MP4, WAV, M4A, WebM, AVI, MOV)
- 💼 **Cross-platform** - Works on Windows, macOS, and Linux

### Mobile App (Android)
- 🔐 **Device Binding** - Content only works on authorized devices
- 🗃️ **Encrypted Storage** - Media files encrypted on disk
- 📊 **Usage Tracking** - Automatic playback counting and limit enforcement
- ⏰ **Time-based Resets** - Play limits reset after configured interval
- 🎬 **Built-in Player** - Integrated audio/video player
- ✈️ **Offline First** - No internet connection required

### Security Features
- Device-specific encryption prevents unauthorized access
- Bundled media cannot be extracted or shared
- Playback limits enforced with timer restrictions
- Anti-sharing protections prevent content redistribution
- No cloud dependencies - everything works offline

## Security model at a glance

- Device binding: Android ID allowlist checked on import
- Content keys: A random per-bundle key is wrapped per authorized device (CryptoJS/OpenSSL-compatible). The mobile app unwraps it in-memory only.
- Media protection: xor-v1 streaming obfuscation keyed by the bundle key and per-file salt (current default); legacy bundles may use AES-256-CBC with OpenSSL salted headers.
- Configuration: Bundle config is encrypted with a shared config key.
- Integrity: Checksums and integrity fields detect tampering.
- Limitations: Rooted devices, screen recording, and time manipulation are partially or not mitigated. See TECHNICAL.md for details.

## Project Structure

```
scripture_media_trial_content_app/
├── shared/                 # Shared utilities and business logic
│   ├── src/
│   │   ├── encryption.js        # AES encryption utilities
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
└── package.json           # Root package with workspaces
```

## Quick Start

### Prerequisites
- Node.js 16.x or higher
- npm 8.x or higher
- For mobile development: Flutter SDK, Android Studio, JDK 11+, Android SDK

### Installation

```bash
# Clone the repository
git clone https://github.com/rulingAnts/scripture_media_trial_content_app.git
cd scripture_media_trial_content_app

# Install dependencies
npm install
```

### Run Desktop Bundler

```bash
npm run desktop
```

### Run Mobile App (Android)

```bash
cd mobile_app
flutter pub get
flutter run

# Or use the build script
scripts/build_apk.sh
```

## Documentation

### Getting Started
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup and quick start guide
- **[USER_GUIDE.md](USER_GUIDE.md)** - Detailed usage instructions and troubleshooting
- **[TECHNICAL.md](TECHNICAL.md)** - Architecture, security, and implementation details
- **[COMMUNITY.md](COMMUNITY.md)** - FAQ, contributing guidelines, and support
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes

## Workflow Overview

1. **Content Creator** uses Desktop Bundler to:
   - Add media files
   - Specify authorized device IDs
   - Set playback limits (e.g., 3 plays per 24 hours)
   - Create encrypted bundle

2. **Distribution**:
   - Bundle is a portable folder
   - Share via any file transfer method
   - Each reviewer gets the same bundle

3. **Reviewer** uses Mobile App to:
   - Import bundle
   - App verifies device authorization
   - Play media within limits
   - Provide feedback

## Technology Stack

- **Desktop App**: Electron, Node.js, vanilla JavaScript
- **Mobile App**: Flutter, Dart, Android
- **Encryption**: AES-256 via CryptoJS (desktop), encrypt package (mobile)
- **Storage**: File system (desktop), SharedPreferences (mobile)

## License

MIT License - See [LICENSE](LICENSE) file for details

## Contributing

This is a specialized application for secure content distribution. Contributions are welcome, especially for:
- Security improvements
- Additional platform support
- Enhanced encryption methods
- UI/UX improvements

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

## Security Note

This application implements multiple security layers but is not impenetrable. For high-value content, combine with:
- Legal agreements
- User education
- Monitoring and auditing
- Regular security updates

See [TECHNICAL.md#security](TECHNICAL.md#security) for detailed security analysis.
