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

## Bundle Directory Structure

When you create a bundle, you'll get a directory like this:

```
bundle_Luke_Gospel_Trial_1234567890/
├── bundle.json                                 # Configuration file
├── README.txt                                  # Instructions
└── media/                                      # Encrypted media files
    ├── 550e8400-e29b-41d4-a716-446655440001.enc
    └── 550e8400-e29b-41d4-a716-446655440002.enc
```

## Usage

1. **Desktop App**: Creates bundles with this structure
2. **Mobile App**: Reads `bundle.json` and imports encrypted media files
3. **Distribution**: Share the entire bundle directory

## Notes

- Never modify `bundle.json` manually (it may break validation)
- Never decrypt `.enc` files manually (they're device-specific)
- Always transfer the complete bundle directory
- Keep device IDs confidential
