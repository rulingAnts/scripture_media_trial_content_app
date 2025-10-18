# Contributing to Scripture Media Trial Content App

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain professional communication

## How to Contribute

### Reporting Issues

Before creating an issue:
1. Check if the issue already exists
2. Use the issue template if available
3. Provide detailed information:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, versions)
   - Screenshots if applicable

### Suggesting Features

When suggesting features:
1. Explain the use case
2. Describe the proposed solution
3. Consider security implications
4. Discuss alternatives

### Security Issues

**Do NOT** report security issues publicly. Instead:
1. Email security concerns privately
2. Provide detailed information
3. Allow time for response and fix
4. Coordinate disclosure

## Development Process

### Setting Up Development Environment

1. Fork the repository
2. Clone your fork
3. Install dependencies: `npm install`
4. Create a branch: `git checkout -b feature/your-feature`

### Code Standards

**JavaScript:**
- Use meaningful variable names
- Add comments for complex logic
- Follow existing code style
- Use modern ES6+ syntax

**React Native:**
- Functional components with hooks
- Keep components focused and small
- Handle errors gracefully
- Test on real devices

**Security:**
- Never log sensitive data
- Validate all inputs
- Use secure coding practices
- Consider threat model

### Testing

Before submitting:
1. Test functionality manually
2. Verify on multiple devices/platforms
3. Check for console errors
4. Test edge cases

### Commit Messages

Format: `type: description`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Build/tooling changes

Example: `feat: add bundle import UI to mobile app`

### Pull Requests

1. **Create PR** from your feature branch
2. **Describe changes** clearly
3. **Link issues** if applicable
4. **Request review** from maintainers
5. **Address feedback** promptly

PR checklist:
- [ ] Code follows project style
- [ ] Changes are tested
- [ ] Documentation updated
- [ ] No security issues introduced
- [ ] Commit messages are clear

## Areas for Contribution

### High Priority
- Mobile app bundle import UI
- Root detection for Android
- Tamper detection
- Code obfuscation
- Automated tests

### Medium Priority
- iOS support
- Screen recording detection
- Watermarking
- Progress indicators
- Error handling improvements

### Nice to Have
- Multi-language support
- Accessibility features
- Analytics (privacy-preserving)
- Advanced playback features
- Batch bundle operations

## Development Guidelines

### Mobile App

**File Organization:**
- Keep components in `src/` directory
- Separate business logic from UI
- Use existing patterns

**Performance:**
- Minimize re-renders
- Clean up resources
- Test on low-end devices
- Monitor memory usage

**Security:**
- Use SecureStorage for sensitive data
- Validate device authorization
- Never expose decrypted content
- Clean up temporary files

### Desktop App

**File Organization:**
- Main process in `main.js`
- Renderer in `renderer.js`
- Keep IPC handlers organized

**User Experience:**
- Clear error messages
- Progress feedback
- Input validation
- Help text where needed

**Security:**
- Validate file paths
- Sanitize user inputs
- Handle errors gracefully
- Secure file operations

### Shared Library

**Code Quality:**
- Well-documented functions
- Unit testable
- No side effects
- Platform-agnostic

**API Design:**
- Clear function names
- Consistent parameters
- Good error messages
- Type documentation

## Review Process

1. **Automated checks** must pass
2. **Code review** by maintainer
3. **Testing** on target platforms
4. **Security review** for sensitive changes
5. **Documentation** review if needed

## Release Process

Maintainers handle releases:
1. Version bump
2. Changelog update
3. Build creation
4. Testing
5. Publication
6. Announcement

## Getting Help

- Open an issue for questions
- Check existing documentation
- Review closed issues/PRs
- Ask in discussions

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing!
