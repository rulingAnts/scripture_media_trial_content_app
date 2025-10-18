# Scripture Media Trial Content App - Setup Guide

This application consists of two main components:
1. **Mobile App** - Android app for playing restricted media content
2. **Desktop App** - Desktop application for creating and bundling media content

## Prerequisites

### For Desktop App Development
- Node.js 16.x or higher
- npm 8.x or higher

### For Mobile App Development
- Node.js 16.x or higher
- npm 8.x or higher
- React Native CLI
- Android Studio (for Android development)
- JDK 11 or higher
- Android SDK

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/rulingAnts/scripture_media_trial_content_app.git
cd scripture_media_trial_content_app
```

### 2. Install Root Dependencies

```bash
npm install
```

This will install dependencies for all workspaces (shared, mobile-app, desktop-app).

### 3. Setup Individual Components

#### Desktop App
```bash
cd desktop-app
npm install
```

#### Mobile App
```bash
cd mobile-app
npm install
```

#### Shared Library
```bash
cd shared
npm install
```

## Running the Applications

### Desktop Bundler App

From the root directory:
```bash
npm run desktop
```

Or from the desktop-app directory:
```bash
cd desktop-app
npm start
```

### Mobile App

#### Android

1. Start the Metro bundler:
```bash
cd mobile-app
npm start
```

2. In another terminal, run on Android:
```bash
cd mobile-app
npm run android
```

Or use Android Studio to open the `mobile-app/android` folder and run the app.

## Building for Production

### Desktop App

Build for your platform:

```bash
cd desktop-app

# Windows
npm run build:win

# macOS
npm run build:mac

# Linux
npm run build:linux
```

The built application will be in `desktop-app/dist/`.

### Mobile App

#### Android Release Build

```bash
cd mobile-app
npm run build
```

The APK will be in `mobile-app/android/app/build/outputs/apk/release/`.

## Development Setup

### Android Development Setup

1. Install Android Studio from https://developer.android.com/studio
2. Install Android SDK Platform 33 (or higher)
3. Set up environment variables:
   - `ANDROID_HOME` - path to Android SDK
   - Add `platform-tools` to PATH

4. Configure Android Virtual Device (AVD) or connect a physical device

### React Native Environment

Follow the official React Native environment setup guide:
https://reactnative.dev/docs/environment-setup

Select "React Native CLI Quickstart" for your development OS and target OS (Android).

## Troubleshooting

### Desktop App Issues

**Electron not starting:**
```bash
cd desktop-app
rm -rf node_modules package-lock.json
npm install
```

### Mobile App Issues

**Metro bundler cache issues:**
```bash
cd mobile-app
npm start -- --reset-cache
```

**Android build failures:**
```bash
cd mobile-app/android
./gradlew clean
cd ..
npm run android
```

**Dependency resolution issues:**
```bash
cd mobile-app
rm -rf node_modules package-lock.json
npm install
cd android
./gradlew clean
```

## Next Steps

1. Read [USAGE.md](USAGE.md) for instructions on how to use the applications
2. Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the system design
3. Review security considerations in [SECURITY.md](SECURITY.md)
