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
├── mobile-app/            # React Native Android app
│   ├── src/
│   │   ├── DeviceBinding.js     # Device identification
│   │   ├── SecureStorage.js     # Encrypted file management
│   │   ├── BundleManager.js     # Bundle loading
│   │   └── MediaPlayer.js       # Playback with limits
│   ├── App.js
│   └── package.json
└── package.json           # Root package with workspaces
```

## Quick Start

### Prerequisites
- Node.js 16.x or higher
- npm 8.x or higher
- For mobile development: Android Studio, JDK 11+, Android SDK

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
# Terminal 1 - Start Metro bundler
npm run mobile

# Terminal 2 - Run on Android device/emulator
cd mobile-app
npm run android
```

## Documentation

### Getting Started
- **[QUICKSTART.md](QUICKSTART.md)** - Get up and running in 5-10 minutes
- **[SETUP.md](SETUP.md)** - Complete setup and installation guide
- **[USAGE.md](USAGE.md)** - How to use the desktop and mobile apps

### Technical Documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design and technical details
- **[SECURITY.md](SECURITY.md)** - Security analysis and best practices

### Reference
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute to the project
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
- **[examples/](examples/)** - Example bundle configurations

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
- **Mobile App**: React Native, Android
- **Encryption**: AES-256 via crypto-js
- **Storage**: File system (desktop), AsyncStorage + RNFS (mobile)

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

See [SECURITY.md](SECURITY.md) for detailed security analysis.
