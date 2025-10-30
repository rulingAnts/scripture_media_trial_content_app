# Examples

This directory contains example files to help you understand the bundle structure.

## example-bundle-config.json

This is an example of what a bundle configuration file looks like. When you create a bundle using the Desktop Bundler App, it generates a file like this.

### Key Fields:

- **bundleId**: Unique identifier for the bundle
- **allowedDeviceIds**: Array of device IDs that can access this bundle
- **mediaFiles**: Array of media file objects, each containing:
  - **id**: Unique UUID for the media file
  - **fileName**: Original file name
  - **title**: Display title
  - **type**: "audio" or "video"
  - **encryptedPath**: Relative path to encrypted file
  - **checksum**: SHA-256 hash of original file
  - **playbackLimit**: Limits for this specific file
- **playbackLimits.default**: Default limits for all files

# Examples

This directory contains example files to help you understand the bundle structure.

## example-bundle-config.json

This is an example of what a bundle configuration file looks like. When you create a bundle using the Desktop Bundler App, it generates a file like this.

### Key Fields:

- **bundleId**: Unique identifier for the bundle
- **allowedDeviceIds**: Array of device IDs that can access this bundle
- **mediaFiles**: Array of media file objects, each containing:
  - **id**: Unique UUID for the media file
  - **fileName**: Original file name
  - **title**: Display title
  - **type**: "audio" or "video"
  - **encryptedPath**: Relative path to encrypted file
  - **checksum**: SHA-256 hash of original file
  - **playbackLimit**: Limits for this specific file
- **playbackLimits.default**: Default limits for all files

## Bundle Archive Structure (Version 2.0)

When you create a bundle, you'll get a secure `.smbundle` file:

```
bundle_Luke_Gospel_Trial_1234567890.smbundle  # Compressed, encrypted archive
└── (extracted contents):
    ├── bundle.smb                             # Encrypted configuration file
    ├── README.txt                             # Instructions
    ├── manifest.json                          # Bundle metadata
    └── media/                                 # Encrypted media files
        ├── 550e8400-e29b-41d4-a716-446655440001.enc
        └── 550e8400-e29b-41d4-a716-446655440002.enc
```

## Security Features

### Version 2.0 Security Enhancements:
- **Encrypted Configuration**: The `bundle.smb` file contains encrypted bundle configuration that can only be decrypted by authorized devices
- **Compressed Archive**: Bundle is a `.smbundle` (tar.gz) file with custom extension to prevent easy modification
- **Integrity Verification**: Built-in checksums and integrity verification prevent tampering
- **Device-Specific Decryption**: Bundle configuration is encrypted with device-specific keys

### Anti-Tampering Measures:
- Configuration file is encrypted and cannot be easily modified
- Archive format prevents simple extraction and re-packaging
- Custom file extension (.smbundle) discourages casual modification
- Integrity checks detect any modifications to the bundle contents

## Usage

1. **Desktop App**: Creates secure `.smbundle` archives
2. **Mobile App**: Extracts and validates `.smbundle` files
3. **Distribution**: Share the `.smbundle` file (not a folder)

## Legacy Support

The mobile app still supports legacy `bundle.json` files for backwards compatibility, but new bundles created with the desktop app use the secure `.smbundle` format.

## Notes

- Never attempt to modify `.smbundle` files (they will become unusable)
- The bundle configuration is encrypted with device-specific keys
- Always transfer the complete `.smbundle` file
- Keep device IDs confidential
