import AsyncStorage from '@react-native-async-storage/async-storage';
import RNFS from 'react-native-fs';
import { validateBundleConfig } from '@scripture-media/shared';
import DeviceBinding from './DeviceBinding';
import SecureStorage from './SecureStorage';

/**
 * Manages bundle loading and validation
 */
class BundleManager {
  constructor() {
    this.currentBundle = null;
  }

  /**
   * Loads a bundle from a file
   * @param {string} bundlePath - Path to the bundle file
   * @returns {Promise<Object>} - Bundle configuration
   */
  async loadBundle(bundlePath) {
    try {
      // Read bundle file
      const bundleData = await RNFS.readFile(bundlePath, 'utf8');
      const bundle = JSON.parse(bundleData);

      // Validate bundle structure
      const validation = validateBundleConfig(bundle);
      if (!validation.isValid) {
        throw new Error(`Invalid bundle: ${validation.errors.join(', ')}`);
      }

      // Check device authorization
      const isAllowed = await DeviceBinding.isDeviceAllowed(bundle.allowedDeviceIds);
      if (!isAllowed) {
        const deviceId = await DeviceBinding.getDeviceId();
        throw new Error(`Device ${deviceId} is not authorized for this bundle`);
      }

      // Store bundle configuration
      await AsyncStorage.setItem('current_bundle', JSON.stringify(bundle));
      this.currentBundle = bundle;

      return bundle;
    } catch (error) {
      console.error('Failed to load bundle:', error);
      throw error;
    }
  }

  /**
   * Gets the current bundle
   * @returns {Promise<Object|null>} - Current bundle or null
   */
  async getCurrentBundle() {
    if (this.currentBundle) {
      return this.currentBundle;
    }

    try {
      const bundleData = await AsyncStorage.getItem('current_bundle');
      if (bundleData) {
        this.currentBundle = JSON.parse(bundleData);
        return this.currentBundle;
      }
    } catch (error) {
      console.error('Failed to get current bundle:', error);
    }

    return null;
  }

  /**
   * Gets all media files in the current bundle
   * @returns {Promise<Array>} - List of media files
   */
  async getMediaFiles() {
    const bundle = await this.getCurrentBundle();
    if (!bundle) {
      return [];
    }

    return bundle.mediaFiles || [];
  }

  /**
   * Gets a specific media file by ID
   * @param {string} mediaId - The media file ID
   * @returns {Promise<Object|null>} - Media file object or null
   */
  async getMediaFile(mediaId) {
    const mediaFiles = await this.getMediaFiles();
    return mediaFiles.find(file => file.id === mediaId) || null;
  }

  /**
   * Imports media files from a bundle directory
   * @param {string} bundleDir - Directory containing the bundle
   * @returns {Promise<number>} - Number of files imported
   */
  async importMediaFiles(bundleDir) {
    const bundle = await this.getCurrentBundle();
    if (!bundle) {
      throw new Error('No bundle loaded');
    }

    let importedCount = 0;

    for (const mediaFile of bundle.mediaFiles) {
      try {
        const sourcePath = `${bundleDir}/${mediaFile.encryptedPath}`;
        
        // Check if source file exists
        const exists = await RNFS.exists(sourcePath);
        if (!exists) {
          console.warn(`Media file not found: ${sourcePath}`);
          continue;
        }

        // Read encrypted file
        const encryptedData = await RNFS.readFile(sourcePath, 'base64');
        
        // Store in secure storage
        await SecureStorage.storeMediaFile(mediaFile.id, encryptedData);
        
        importedCount++;
      } catch (error) {
        console.error(`Failed to import media file ${mediaFile.id}:`, error);
      }
    }

    return importedCount;
  }

  /**
   * Clears the current bundle and all associated media
   */
  async clearBundle() {
    try {
      const mediaFiles = await this.getMediaFiles();
      
      // Delete all media files
      for (const mediaFile of mediaFiles) {
        await SecureStorage.deleteMediaFile(mediaFile.id);
      }

      // Clear bundle configuration
      await AsyncStorage.removeItem('current_bundle');
      this.currentBundle = null;
    } catch (error) {
      console.error('Failed to clear bundle:', error);
      throw error;
    }
  }
}

export default new BundleManager();
