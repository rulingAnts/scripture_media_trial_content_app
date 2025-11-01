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

### Testing Infrastructure
- Unit tests for encryption utilities
- Integration tests for bundle workflows
- Automated security testing
- Cross-device compatibility testing

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
