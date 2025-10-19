const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs').promises;
const crypto = require('crypto');

/**
 * APK Builder module for creating Android APKs with embedded bundles
 */
class APKBuilder {
  constructor() {
    this.mobileAppPath = path.resolve(__dirname, '../../mobile-app');
    this.tempDir = path.join(__dirname, '../temp');
  }

  /**
   * Checks if all required tools are available for APK building
   * @returns {Promise<{valid: boolean, errors: string[]}>}
   */
  async validateEnvironment() {
    const errors = [];

    try {
      // Check if React Native CLI is available
      await this.runCommand('npx', ['react-native', '--version'], { timeout: 10000 });
    } catch (error) {
      errors.push('React Native CLI not found. Install with: npm install -g @react-native-community/cli');
    }

    try {
      // Check if Android SDK is available
      const androidHome = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT;
      if (!androidHome) {
        errors.push('ANDROID_HOME environment variable not set');
      } else {
        // Check if gradlew exists in mobile app
        const gradlewPath = path.join(this.mobileAppPath, 'android', 'gradlew');
        try {
          await fs.access(gradlewPath);
        } catch {
          errors.push('Android project not initialized. Run "npx react-native run-android" first');
        }
      }
    } catch (error) {
      errors.push('Android SDK not properly configured');
    }

    try {
      // Check if Java/JDK is available
      await this.runCommand('java', ['-version'], { timeout: 5000 });
    } catch (error) {
      errors.push('Java JDK not found. Install JDK 11 or higher');
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Builds an APK with the given bundle embedded
   * @param {Object} options - Build options
   * @param {string} options.bundleDir - Path to the bundle directory
   * @param {string} options.bundleConfig - Bundle configuration object
   * @param {string} options.outputDir - Directory to save the APK
   * @param {string} options.appName - Name for the APK
   * @param {Function} options.onProgress - Progress callback
   * @returns {Promise<{success: boolean, apkPath?: string, error?: string}>}
   */
  async buildAPK(options) {
    const { bundleDir, bundleConfig, outputDir, appName, onProgress } = options;

    try {
      onProgress?.('Validating environment...');
      const validation = await this.validateEnvironment();
      if (!validation.valid) {
        throw new Error(`Environment validation failed:\n${validation.errors.join('\n')}`);
      }

      onProgress?.('Setting up build environment...');
      await this.setupBuildEnvironment();

      onProgress?.('Embedding bundle in mobile app...');
      await this.embedBundleInApp(bundleDir, bundleConfig);

      onProgress?.('Installing dependencies...');
      await this.installDependencies();

      onProgress?.('Building Android project...');
      const apkPath = await this.buildAndroidAPK(outputDir, appName);

      onProgress?.('Cleaning up...');
      await this.cleanup();

      return {
        success: true,
        apkPath
      };
    } catch (error) {
      console.error('APK build failed:', error);
      await this.cleanup();
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Sets up the build environment
   */
  async setupBuildEnvironment() {
    // Ensure temp directory exists
    await fs.mkdir(this.tempDir, { recursive: true });

    // Initialize Android project if it doesn't exist
    const androidDir = path.join(this.mobileAppPath, 'android');
    try {
      await fs.access(androidDir);
    } catch {
      // Android project doesn't exist, initialize it
      await this.runCommand('npx', ['react-native', 'run-android', '--no-packager'], {
        cwd: this.mobileAppPath,
        timeout: 120000
      });
    }
  }

  /**
   * Embeds the bundle into the mobile app's assets
   */
  async embedBundleInApp(bundleDir, bundleConfig) {
    const assetsDir = path.join(this.mobileAppPath, 'android', 'app', 'src', 'main', 'assets');
    const bundleAssetsDir = path.join(assetsDir, 'bundle');

    // Create assets directory if it doesn't exist
    await fs.mkdir(assetsDir, { recursive: true });
    await fs.mkdir(bundleAssetsDir, { recursive: true });

    // Copy bundle.json
    const bundleJsonSource = path.join(bundleDir, 'bundle.json');
    const bundleJsonDest = path.join(bundleAssetsDir, 'bundle.json');
    await fs.copyFile(bundleJsonSource, bundleJsonDest);

    // Copy media directory
    const mediaSourceDir = path.join(bundleDir, 'media');
    const mediaDestDir = path.join(bundleAssetsDir, 'media');
    await this.copyDirectory(mediaSourceDir, mediaDestDir);

    // Create a marker file to indicate this is an embedded bundle
    const markerFile = path.join(bundleAssetsDir, '.embedded');
    await fs.writeFile(markerFile, JSON.stringify({
      embedded: true,
      bundleId: bundleConfig.bundleId,
      createdAt: new Date().toISOString(),
      appVersion: '1.0.0'
    }), 'utf8');
  }

  /**
   * Installs mobile app dependencies
   */
  async installDependencies() {
    await this.runCommand('npm', ['install'], {
      cwd: this.mobileAppPath,
      timeout: 300000 // 5 minutes
    });
  }

  /**
   * Builds the Android APK
   */
  async buildAndroidAPK(outputDir, appName) {
    const androidDir = path.join(this.mobileAppPath, 'android');
    
    // Clean previous builds
    await this.runCommand('./gradlew', ['clean'], {
      cwd: androidDir,
      timeout: 60000
    });

    // Build release APK
    await this.runCommand('./gradlew', ['assembleRelease'], {
      cwd: androidDir,
      timeout: 600000 // 10 minutes
    });

    // Find the generated APK
    const apkSourcePath = path.join(androidDir, 'app', 'build', 'outputs', 'apk', 'release', 'app-release.apk');
    
    // Copy APK to output directory with custom name
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const apkFileName = `${appName}_${timestamp}.apk`;
    const apkDestPath = path.join(outputDir, apkFileName);
    
    await fs.copyFile(apkSourcePath, apkDestPath);
    
    return apkDestPath;
  }

  /**
   * Cleans up temporary files and resets the mobile app
   */
  async cleanup() {
    try {
      // Remove embedded bundle from assets
      const bundleAssetsDir = path.join(this.mobileAppPath, 'android', 'app', 'src', 'main', 'assets', 'bundle');
      await this.removeDirectory(bundleAssetsDir);

      // Clean build directory
      const androidDir = path.join(this.mobileAppPath, 'android');
      await this.runCommand('./gradlew', ['clean'], {
        cwd: androidDir,
        timeout: 60000
      });
    } catch (error) {
      console.warn('Cleanup warning:', error.message);
    }
  }

  /**
   * Runs a command and returns a promise
   */
  runCommand(command, args = [], options = {}) {
    return new Promise((resolve, reject) => {
      const { timeout = 30000, cwd } = options;
      
      const process = spawn(command, args, {
        cwd: cwd || process.cwd(),
        stdio: 'pipe',
        shell: true
      });

      let stdout = '';
      let stderr = '';

      process.stdout?.on('data', (data) => {
        stdout += data.toString();
      });

      process.stderr?.on('data', (data) => {
        stderr += data.toString();
      });

      const timer = setTimeout(() => {
        process.kill();
        reject(new Error(`Command timed out after ${timeout}ms: ${command} ${args.join(' ')}`));
      }, timeout);

      process.on('close', (code) => {
        clearTimeout(timer);
        if (code === 0) {
          resolve(stdout);
        } else {
          reject(new Error(`Command failed with code ${code}: ${command} ${args.join(' ')}\n${stderr}`));
        }
      });

      process.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
  }

  /**
   * Recursively copies a directory
   */
  async copyDirectory(source, destination) {
    await fs.mkdir(destination, { recursive: true });
    
    const entries = await fs.readdir(source, { withFileTypes: true });
    
    for (const entry of entries) {
      const sourcePath = path.join(source, entry.name);
      const destPath = path.join(destination, entry.name);
      
      if (entry.isDirectory()) {
        await this.copyDirectory(sourcePath, destPath);
      } else {
        await fs.copyFile(sourcePath, destPath);
      }
    }
  }

  /**
   * Recursively removes a directory
   */
  async removeDirectory(dirPath) {
    try {
      await fs.rm(dirPath, { recursive: true, force: true });
    } catch (error) {
      // Ignore errors if directory doesn't exist
      if (error.code !== 'ENOENT') {
        throw error;
      }
    }
  }
}

module.exports = APKBuilder;