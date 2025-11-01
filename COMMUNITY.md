# Community & Support

Frequently asked questions, contributing guidelines, and support resources.

## Table of Contents

- [Frequently Asked Questions](#frequently-asked-questions)
- [Contributing](#contributing)
- [Support](#support)

## Frequently Asked Questions

### General Questions

#### What is this application for?

This app allows content creators to share trial media content (like audio/video scripture recordings) with a limited audience before final approval. The content is:
- Locked to specific devices (Android ID–based)
- Limited in how many times it can be played
- Protected at rest (encryption/obfuscation) to deter extraction
- Designed to discourage unauthorized sharing

#### Who should use this?

- **Content Creators**: Organizations preparing scripture translations for review
- **Reviewers**: Selected individuals who need to review trial content
- **Translators**: Teams working on pre-release scripture media

#### Do I need internet to use this?

No! This app works completely offline. No internet connection is required for:
- Creating bundles (desktop)
- Playing media (mobile)
- Tracking playback limits

#### What platforms are supported?

- **Desktop Bundler**: Windows, macOS (via Electron)
- **Mobile App**: Android

### Security Questions

#### How secure is this?

The app uses multiple security layers:
- Device binding (Android ID allowlist)
- Per-device wrapped content keys inside the bundle
- Media protection at rest (xor-v1 obfuscation by default; legacy AES-256-CBC supported)
- Playback tracking and limits
- No export functionality

However, it is not impenetrable. See [TECHNICAL.md](TECHNICAL.md) for a detailed security analysis and residual risks.

#### Can content be extracted from the app?

Not easily. Media files are:
- Protected at rest and not playable outside the app
- Only decrypted/deobfuscated temporarily during playback
- Automatically cleaned up after use
- Stored in the app's private directory

However, users with root access or advanced tools could potentially extract content.

#### What if someone shares the APK?

The APK can be shared, but it won't help unauthorized users:
- Bundle verifies device authorization on load
- Content keys are device-bound; unauthorized devices can't unwrap the key
- Media won't decrypt/deobfuscate on unauthorized devices

#### Can users screen record the content?

Yes, unfortunately. Android doesn't provide reliable screen recording prevention. Consider this a limitation and use legal agreements and/or visible watermarks to discourage it.

#### What happens if a device is rooted?

Rooted devices can potentially bypass security measures:
- Access encrypted files
- Modify playback tracking
- Extract encryption keys

Current version doesn't detect root. This is a known limitation.

### Technical Questions

#### How are Device IDs generated?

Device IDs come from Android's software identifier (Android ID):
- Set by the OS (not a hardware serial)
- Persists across app reinstalls and OS updates
- Changes on factory reset
- Difficult to change without root access or device reset

#### How does encryption work?

v2.1+ bundles (current default):
1. Desktop generates a random per-bundle content key
2. For each authorized device ID, derive a wrapping key via SHA-256(deviceId + salt)
3. Encrypt ("wrap") the bundle content key per device (OpenSSL-compatible CryptoJS format)
4. Protect media files using a fast, streaming scheme (xor-v1) keyed with the bundle key and per-file salt
5. Mobile unwraps the bundle key using the device-derived wrapping key, then deobfuscates media on-the-fly during playback

Legacy bundles (v2.0 and earlier):
- Media may be encrypted with AES-256-CBC (OpenSSL salted header), using a key derived from the device ID
- Mobile supports streaming decryption of this format for large files

#### What happens when playback limit is reached?

- Play button becomes disabled
- Message shows when limit resets
- After reset interval, plays become available again
- Example: 3 plays per 24 hours means 3 plays, then wait 24 hours

#### How is playback tracked?

- Each play is timestamped
- Timestamps stored in SharedPreferences
- On each play attempt, app checks recent timestamps
- Old timestamps (outside reset interval) are ignored

#### Can users bypass playback limits?

Potentially, yes:
- Clearing app data resets counters (loses bundle too)
- Changing system time affects reset intervals (triggers tamper detection)
- Root access can modify storage

These are known limitations. For critical use cases, combine with user agreements.

#### What media formats are supported?

**Audio**: MP3, WAV, M4A  
**Video**: MP4, WebM, AVI, MOV

Most common formats work. If a format doesn't work, convert it before bundling.

### Usage Questions

#### How do I get my device ID?

1. Install the mobile app
2. Launch it
3. Device ID is displayed on the welcome screen
4. Copy it and share with content creator

Alternatively, use ADB:
```bash
adb shell settings get secure android_id
```

#### How do I import a bundle?

With file association (automatic):
1. Receive `.smbundle` file on your device
2. Tap the file in file manager, email, or messaging app
3. Select "Scripture Demo Player" when prompted
4. Bundle automatically imports

#### Can I use multiple bundles?

Currently, only one bundle can be active on the device at a time:
- Importing a new bundle replaces the previously active bundle’s content
- Previously used (older) bundles cannot be re-activated (anti-rollback)
- Each new bundle carries its own limits and expiration

If you need to compare or switch between bundles regularly, let us know—adding a bundle selector is feasible, but we prioritize preventing rollbacks that could weaken security policies.

#### What if I reach playback limit?

Wait for the reset interval to pass:
- Check "Next reset time" in the app
- After that time, plays become available
- Contact content creator if limits need adjustment

#### Can I backup my bundles?

No built-in backup, by design:
- Bundles are device-restricted
- Backup/restore could bypass security
- Keep original bundle files on computer
- Re-import if needed

#### What happens if I factory reset?

Factory reset changes device ID, so:
- Your device won't be authorized anymore
- Content won't decrypt
- Need new bundle with new device ID

#### Can I transfer content to a new device?

No, content is device-specific by design:
- Access is bound to authorized device IDs
- Won't work on a different device that isn't authorized
- Request a new bundle for the new device

### Content Creation Questions

#### How many device IDs can I authorize?

Unlimited! Add as many device IDs as needed:
- One per line in desktop app
- All authorized devices use the same bundle file
- Each device has its own wrapped content key inside the bundle (no separate bundles required)

#### Can I update a bundle after creation?

No, bundles are immutable. To update:
- Create a new bundle
- Distribute to reviewers
- Reviewers delete old bundle and import new one

#### How should I name bundles?

Suggested format: `{Content}_{Version}_{Date}`

Examples:
- `Luke_Gospel_v1_20240115`
- `Genesis_Chapters1-10_Trial_Jan2024`
- `Psalms_AudioTest_20240115`

#### What playback limits should I set?

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

#### How do I distribute bundles?

Options:
- Email (attach `.smbundle` file)
- Cloud storage (Google Drive, Dropbox)
- Messaging apps (WhatsApp, Telegram)
- USB drive
- Direct transfer

Always use secure channels and don't post publicly.

#### Can I revoke access after distribution?

No remote revocation currently. However:
- Don't share bundle publicly
- Track who has which bundles
- Create new bundles for updates
- Use expiration dates for time-limited access

### Development Questions

#### What technologies are used?

- **Desktop**: Electron, Node.js, JavaScript
- **Mobile**: Flutter, Dart, Android
- **Shared**: JavaScript, CryptoJS
- **Protection**: AES-256-CBC (legacy), xor-v1 obfuscation (current default for media), SHA-256 for key derivation

#### Where should I start learning the codebase?

1. Read [TECHNICAL.md](TECHNICAL.md)
2. Look at shared library (simplest)
3. Explore desktop app (Electron)
4. Study mobile app (Flutter)

#### Can I use this for non-scripture content?

Yes! The app is designed for scripture media but works for any media content requiring:
- Device restrictions
- Playback limits
- Secure distribution
- Offline access

Just replace branding and adjust for your use case.

## Contributing

Thank you for your interest in contributing!

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain professional communication

### How to Contribute

#### Reporting Issues

Before creating an issue:
1. Check if the issue already exists
2. Search closed issues
3. Provide detailed information:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, versions)
   - Screenshots if applicable
   - Error messages and logs

#### Suggesting Features

When suggesting features:
1. Explain the use case
2. Describe the proposed solution
3. Consider security implications
4. Discuss alternatives
5. Check if already requested

#### Security Issues

**Do NOT** report security issues publicly. Instead:
1. Email security concerns privately to repository owner
2. Provide detailed information
3. Allow time for response and fix
4. Coordinate disclosure

### Development Process

#### Setting Up Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/scripture_media_trial_content_app.git
   cd scripture_media_trial_content_app
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Create a branch:
   ```bash
   git checkout -b feature/your-feature
   ```

#### Code Standards

**JavaScript** (Desktop/Shared):
- ES6+ syntax
- Clear variable names
- Comments for complex logic
- Consistent formatting

**Dart** (Mobile):
- Follow Dart style guide
- Use `flutter analyze`
- Document public APIs
- Handle errors properly

#### Making Changes

1. **Write Tests**: Add tests for new features (when test infrastructure available)
2. **Follow Style**: Match existing code style
3. **Document**: Update documentation for user-facing changes
4. **Commit**: Write clear commit messages
   ```
   feat: Add playlist-level playback limits
   fix: Resolve bundle import issue on Android 14
   docs: Update getting started guide
   ```

#### Submitting Pull Requests

1. Update your fork:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```
2. Push your branch:
   ```bash
   git push origin feature/your-feature
   ```
3. Open a pull request
4. Describe your changes:
   - What problem does it solve?
   - How does it work?
   - Any breaking changes?
   - Screenshots (for UI changes)

#### Code Review Process

1. Maintainers review your PR
2. Address feedback
3. Update your branch if needed
4. Once approved, PR will be merged
5. Delete your branch after merge

### Development Guidelines

#### Desktop App

- Use Electron IPC for main/renderer communication
- Validate all user inputs
- Handle file operations safely
- Provide user feedback for long operations
- Support Windows and macOS (Linux as feasible)

#### Mobile App

- Test on multiple Android versions
- Handle permissions properly
- Optimize battery usage
- Follow Material Design guidelines
- Support different screen sizes

#### Security

- Never store keys on disk
- Encrypt sensitive data or protect with streaming obfuscation

- Validate all inputs
- Handle errors securely
- Document security decisions

### Areas Needing Contribution

**High Priority**:
- iOS support
- Root detection
- Automated testing
- Performance optimizations

**Medium Priority**:
- Screen recording detection
- Watermarking
- Code obfuscation
- Additional language support

**Low Priority**:
- UI/UX improvements
- Documentation enhancements
- Example bundles
- Tutorial videos

### Testing

#### Manual Testing

For all changes:
1. Test on desktop app (all platforms if possible)
2. Test on mobile app (multiple Android versions)
3. Verify security features still work
4. Check playback limits enforcement
5. Test with different bundle configurations

#### Future Automated Testing

When test infrastructure is added:
- Unit tests for all utilities
- Integration tests for workflows
- Security tests for encryption
- Performance tests for large files

### Documentation

Update documentation when:
- Adding new features
- Changing user-facing behavior
- Updating security measures
- Modifying APIs

Documentation to update:
- README.md (if affecting overview)
- GETTING_STARTED.md (if affecting setup)
- USER_GUIDE.md (if affecting usage)
- TECHNICAL.md (if affecting architecture)
- CHANGELOG.md (always)

## Support

### Getting Help

#### Documentation

Start with the documentation:
- [README.md](README.md) - Project overview
- [GETTING_STARTED.md](GETTING_STARTED.md) - Setup and basics
- [USER_GUIDE.md](USER_GUIDE.md) - Usage and troubleshooting
- [TECHNICAL.md](TECHNICAL.md) - Architecture and security

#### GitHub Issues

1. **Search first**: Check existing issues (open and closed)
2. **Use templates**: Follow issue templates if provided
3. **Be specific**: Provide detailed information
4. **Be patient**: Maintainers respond when available

#### Community

- **GitHub Discussions**: Ask questions, share ideas
- **GitHub Issues**: Bug reports, feature requests
- **Email**: Security issues only (private)

### Reporting Bugs

Include:
- **Description**: What went wrong?
- **Steps to reproduce**: How to trigger the bug?
- **Expected behavior**: What should happen?
- **Actual behavior**: What actually happens?
- **Environment**:
  - OS and version
  - App version
  - Device model (for mobile)
  - Android version (for mobile)
- **Logs**: Error messages, stack traces
- **Screenshots**: If applicable

### Feature Requests

Include:
- **Use case**: Why is this needed?
- **Proposed solution**: How should it work?
- **Alternatives**: Other ways to solve it?
- **Security impact**: Any security considerations?

### Asking Questions

- **Check FAQ first**: Many questions answered here
- **Search issues**: Question might be answered already
- **Be clear**: Explain what you're trying to do
- **Provide context**: Share relevant information

### Response Times

- **Critical security issues**: 24-48 hours
- **High priority bugs**: 1-2 weeks
- **Feature requests**: Depends on complexity and priority
- **Questions**: As time permits

### License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

This means:
- Free to use
- Free to modify
- Free to distribute
- No warranty provided

### Acknowledgments

- Initial implementation: GitHub Copilot
- Repository owner: rulingAnts
- All contributors

---

## Still Have Questions?

1. Read the [documentation](README.md)
2. Check [GitHub issues](https://github.com/rulingAnts/scripture_media_trial_content_app/issues)
3. Open a [new issue](https://github.com/rulingAnts/scripture_media_trial_content_app/issues/new)
4. For security issues, contact privately (don't post publicly)

We're here to help! 🎉
