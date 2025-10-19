# APK Template Folder

This folder is intended to store a prebuilt Android template APK and optional signing materials to enable the "no-compile" packaging path in the Desktop Bundler.

## Contents (recommended)

- `template.apk` (optional): A prebuilt APK of the Scripture Media mobile app without any embedded bundle. This is injected with bundles by the Desktop Bundler without compiling.
- `keystore.jks` (optional, private): A keystore used to sign APKs.
- `notes.txt` (optional): Anything relevant to your distribution process.

## Security & Git Hygiene

- Do NOT commit private keys/keystores to Git. Add them to `.gitignore`.
- Do NOT commit large binary APKs to Git unless you understand the repo size impact. Prefer distributing template APKs via GitHub Releases or a private download link and place it here locally.

## How the Desktop App Uses This Folder

If you provide `template.apk` here, the Desktop Bundler can package bundles into it without requiring Android build tools:

1. Unzips the template APK
2. Injects the bundle into `assets/bundle/`
3. Re-zips the APK
4. Optionally signs the APK if signing data is provided

## Recommended Workflow

- Maintain a template APK outside of Git or as a Release asset.
- Copy it here locally as `template.apk` when packaging.
- Provide keystore separately and keep it out of version control.
