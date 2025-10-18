# Frequently Asked Questions (FAQ)

## General Questions

### What is this application for?

This app allows content creators to share trial media content (like audio/video scripture recordings) with a limited audience before final approval. The content is:
- Locked to specific devices
- Limited in how many times it can be played
- Encrypted and cannot be extracted
- Designed to prevent unauthorized sharing

### Who should use this?

- **Content Creators**: Organizations preparing scripture translations for review
- **Reviewers**: Selected individuals who need to review trial content
- **Translators**: Teams working on pre-release scripture media

### Do I need internet to use this?

No! This app works completely offline. No internet connection is required for:
- Creating bundles (desktop)
- Playing media (mobile)
- Tracking playback limits

### What platforms are supported?

- **Desktop Bundler**: Windows, macOS, Linux (via Electron)
- **Mobile App**: Android only (currently)
- **Future**: iOS support planned

## Security Questions

### How secure is this?

The app uses multiple security layers:
- AES-256 encryption for media files
- Device-specific encryption keys
- Hardware-based device binding
- Playback tracking and limits
- No export functionality

However, it's not impenetrable. See [SECURITY.md](SECURITY.md) for detailed analysis.

### Can content be extracted from the app?

Not easily. Media files are:
- Encrypted on disk with device-specific keys
- Only decrypted temporarily during playback
- Automatically cleaned up after use
- Stored in app's private directory

However, users with root access or advanced tools could potentially extract content.

### What if someone shares the APK?

The APK can be shared, but it won't help unauthorized users:
- Content is encrypted with device-specific keys
- Bundle verifies device authorization on load
- Media won't decrypt on unauthorized devices

### Can users screen record the content?

Yes, unfortunately. Android doesn't provide reliable screen recording prevention. Consider this a limitation and use legal agreements to discourage it.

### What happens if a device is rooted?

Rooted devices can potentially bypass security measures:
- Access encrypted files
- Modify playback tracking
- Extract encryption keys

Current version doesn't detect root. This is a known limitation.

## Technical Questions

### How are Device IDs generated?

Device IDs come from Android's unique device identifier:
- Based on `ANDROID_ID` or device serial
- Persists across app reinstalls
- Changes on factory reset
- Cannot be easily changed

### How does encryption work?

1. Desktop app encrypts media with device-specific key
2. Key is derived from device ID + salt using SHA-256
3. Media encrypted with AES-256
4. Mobile app derives same key from device ID
5. Decrypts only during playback

### What happens when playback limit is reached?

- Play button becomes disabled
- Message shows when limit resets
- After reset interval, plays become available again
- Example: 3 plays per 24 hours means 3 plays, then wait 24 hours

### How is playback tracked?

- Each play is timestamped
- Timestamps stored in AsyncStorage
- On each play attempt, app checks recent timestamps
- Old timestamps (outside reset interval) are ignored

### Can users bypass playback limits?

Potentially, yes:
- Clearing app data resets counters (loses bundle too)
- Changing system time affects reset intervals
- Root access can modify storage

These are known limitations. For critical use cases, combine with user agreements.

### What media formats are supported?

**Audio**: MP3, WAV, M4A
**Video**: MP4, WebM, AVI, MOV

Most common formats work. If a format doesn't work, convert it before bundling.

## Usage Questions

### How do I get my device ID?

1. Install the mobile app
2. Launch it
3. Device ID is displayed on the welcome screen
4. Copy it and share with content creator

Alternatively, use ADB: `adb shell settings get secure android_id`

### How do I import a bundle?

**Current**: Bundle import UI is not yet implemented. For testing, use ADB to copy files.

**Planned**: Future version will have:
- "Import Bundle" button
- File picker to select bundle.json
- Automatic import and verification

### Can I use multiple bundles?

Yes! You can:
- Import multiple bundles
- Each bundle is independent
- Switch between bundles
- Each has its own playback limits

### What if I reach playback limit?

Wait for the reset interval to pass:
- Check "Next reset time" in the app
- After that time, plays become available
- Contact content creator if limits need adjustment

### Can I backup my bundles?

No built-in backup, by design:
- Bundles are device-specific
- Backup/restore could bypass security
- Keep original bundle files on computer
- Re-import if needed

### What happens if I factory reset?

Factory reset changes device ID, so:
- Your device won't be authorized anymore
- Content won't decrypt
- Need new bundle with new device ID

### Can I transfer content to a new device?

No, content is device-specific by design:
- Encrypted with original device's key
- Won't work on different device
- Need new bundle for new device

## Content Creation Questions

### How many device IDs can I authorize?

Unlimited! Add as many device IDs as needed:
- One per line in desktop app
- All authorized devices use same bundle
- Same encryption key for all

### Can I update a bundle after creation?

No, bundles are immutable. To update:
- Create a new bundle
- Distribute to reviewers
- Reviewers delete old bundle and import new one

### How should I name bundles?

Suggested format: `{Content}_{Version}_{Date}`

Examples:
- `Luke_Gospel_v1_20240115`
- `Genesis_Chapters1-10_Trial_Jan2024`
- `Psalms_AudioTest_20240115`

### What playback limits should I set?

Depends on your use case:

**Short review (days)**:
- Max plays: 3-5
- Reset: 24 hours

**Extended review (weeks)**:
- Max plays: 10
- Reset: 24-48 hours

**Unlimited (for testing)**:
- Max plays: 999
- Reset: 1 hour

### How do I distribute bundles?

Options:
- Email (zip the bundle folder)
- Cloud storage (Google Drive, Dropbox)
- USB drive
- Direct transfer via messaging apps

Always use secure channels and don't post publicly.

### Can I revoke access after distribution?

No remote revocation currently. However:
- Don't share bundle publicly
- Track who has which bundles
- Create new bundles for updates
- Consider time-limited review periods

## Troubleshooting Questions

### Desktop app won't start

Try:
1. Reinstall dependencies: `npm install`
2. Check Node version: `node --version` (need 16+)
3. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Mobile app won't install

Try:
1. Check device connection: `adb devices`
2. Clean build: `cd android && ./gradlew clean`
3. Restart ADB: `adb kill-server && adb start-server`
4. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Bundle creation fails

Common causes:
- Insufficient disk space (need 2x media size)
- Invalid device IDs (check format)
- Corrupted media files (test playing them first)
- Permission issues (check output directory)

### Media won't play

Common causes:
- Device not authorized (check device ID)
- Playback limit reached (wait for reset)
- Corrupted bundle (re-download)
- Wrong device (bundle for different device)

### Where are detailed solutions?

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for comprehensive troubleshooting guide.

## Development Questions

### How do I contribute?

1. Read [CONTRIBUTING.md](CONTRIBUTING.md)
2. Fork the repository
3. Create a feature branch
4. Make changes and test
5. Submit pull request

### What technologies are used?

- **Desktop**: Electron, Node.js, JavaScript
- **Mobile**: React Native, Android
- **Shared**: JavaScript, crypto-js
- **Encryption**: AES-256, SHA-256

### Where should I start learning the codebase?

1. Read [ARCHITECTURE.md](ARCHITECTURE.md)
2. Look at shared library (simplest)
3. Explore desktop app (Electron)
4. Study mobile app (React Native)

### How do I add iOS support?

Major task requiring:
1. React Native iOS setup
2. iOS-specific device identification
3. iOS secure storage implementation
4. Testing on iOS devices
5. Xcode project configuration

Contributions welcome!

### Can I use this for non-scripture content?

Yes! The app is designed for scripture media but works for any media content requiring:
- Device restrictions
- Playback limits
- Secure distribution
- Offline access

Just replace branding and adjust for your use case.

## Legal Questions

### What license is this under?

MIT License - see [LICENSE](LICENSE) file.

This means:
- Free to use
- Free to modify
- Free to distribute
- No warranty provided

### Can I use this commercially?

Yes, MIT license allows commercial use. However:
- Provide attribution
- Include license text
- No warranty
- Use at your own risk

### Does this comply with copyright law?

Technical measures alone don't guarantee compliance. For copyright protection:
- Use legal agreements
- Document authorized users
- Educate users on proper use
- Combine technical + legal measures

### What about DMCA compliance?

The app implements access controls and encryption, which may qualify for DMCA protection. However:
- Consult legal counsel
- Not a substitute for legal agreements
- Security has limitations
- See [SECURITY.md](SECURITY.md)

### Can I modify and rebrand this?

Yes, under MIT license you can:
- Modify the code
- Change branding
- Add features
- Distribute your version

Just include original license and attribution.

## Support Questions

### Where do I report bugs?

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) first
2. Search existing GitHub issues
3. Open new issue with details:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details
   - Error messages

### Where do I ask questions?

- GitHub issues for general questions
- Email for security issues (private)
- Check documentation first
- Search closed issues

### How do I request features?

1. Check if already requested
2. Open GitHub issue
3. Describe use case
4. Explain proposed solution
5. Consider security implications

### Is there a community?

Not yet, but you can:
- Follow the GitHub repository
- Star it to show support
- Contribute improvements
- Help others in issues

### How often is this updated?

Updates depend on:
- Bug reports
- Security issues
- Feature requests
- Contributor availability

Critical security issues are prioritized.

## Future Plans

### What features are planned?

See [CHANGELOG.md](CHANGELOG.md) for roadmap:
- Bundle import UI (high priority)
- iOS support
- Root detection
- Screen recording detection
- Watermarking
- Remote revocation
- Advanced security features

### When will iOS support be added?

No specific timeline. Contributions welcome! Significant work required for iOS implementation.

### Will there be a web version?

Not planned. Web platform has limitations:
- Can't reliably get device ID
- Limited file system access
- Hard to prevent content extraction
- Security constraints

Mobile native apps are more suitable.

### Can I sponsor development?

Not set up currently, but contributions are welcome:
- Code contributions
- Documentation improvements
- Testing and bug reports
- Security audits
- Feature development

---

## Still Have Questions?

1. Read the [documentation](README.md#documentation)
2. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. Search GitHub issues
4. Open a new issue

We're here to help!
