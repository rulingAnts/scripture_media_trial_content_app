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
   * Initializes the bundle manager and checks for embedded bundles
   * @returns {Promise<Object|null>} - Bundle if found and loaded
   */
  async initialize() {
    try {
      // First check for embedded bundle
      const embeddedBundle = await this.loadEmbeddedBundle();
      if (embeddedBundle) {
        return embeddedBundle;
      }

      // Fallback to previously loaded bundle
      return await this.getCurrentBundle();
    } catch (error) {
      console.error('Failed to initialize bundle manager:', error);
      return null;
    }
  }

  /**
   * Checks for and loads an embedded bundle from app assets
   * @returns {Promise<Object|null>} - Embedded bundle if found
   */
  async loadEmbeddedBundle() {
    try {
      // Android assets live under "assets/" and are accessed via readFileAssets
      // Check marker in assets/bundle/.embedded (Android). For iOS, MainBundlePath works.
      let markerData = null;
      try {
        const markerContent = await RNFS.readFileAssets('bundle/.embedded');
        markerData = JSON.parse(markerContent);
      } catch (e) {
        // Not found in Android assets; try iOS bundle path
        try {
          const markerPathIOS = `${RNFS.MainBundlePath}/bundle/.embedded`;
          const markerExistsIOS = await RNFS.exists(markerPathIOS);
          if (!markerExistsIOS) return null;
          const markerContentIOS = await RNFS.readFile(markerPathIOS, 'utf8');
          markerData = JSON.parse(markerContentIOS);
        } catch {
          return null;
        }
      }
      
      if (!markerData.embedded) {
        return null;
      }

      console.log('Found embedded bundle:', markerData.bundleId);

      // Load the embedded bundle.json (Android assets first)
      let bundleData;
      try {
        bundleData = await RNFS.readFileAssets('bundle/bundle.json');
      } catch (e) {
        const bundleJsonPathIOS = `${RNFS.MainBundlePath}/bundle/bundle.json`;
        bundleData = await RNFS.readFile(bundleJsonPathIOS, 'utf8');
      }
      const bundle = JSON.parse(bundleData);

      // Validate bundle structure
      const validation = validateBundleConfig(bundle);
      if (!validation.isValid) {
        throw new Error(`Invalid embedded bundle: ${validation.errors.join(', ')}`);
      }

      // Check device authorization
      const isAllowed = await DeviceBinding.isDeviceAllowed(bundle.allowedDeviceIds);
      if (!isAllowed) {
        const deviceId = await DeviceBinding.getDeviceId();
        throw new Error(`Device ${deviceId} is not authorized for this embedded bundle`);
      }

      // Import media files from embedded assets
      console.log('Importing embedded media files...');
  await this.importEmbeddedMediaFiles(bundle);

      // Store bundle configuration
      await AsyncStorage.setItem('current_bundle', JSON.stringify(bundle));
      await AsyncStorage.setItem('bundle_source', 'embedded');
      
      this.currentBundle = bundle;
      console.log('Embedded bundle loaded successfully');

      return bundle;
    } catch (error) {
      console.error('Failed to load embedded bundle:', error);
      return null;
    }
  }

  /**
   * Imports media files from embedded assets
   * @param {Object} bundle - Bundle configuration
   */
  async importEmbeddedMediaFiles(bundle) {
    let importedCount = 0;

    for (const mediaFile of bundle.mediaFiles) {
      try {
        // Read encrypted file from Android assets or iOS bundle
        let encryptedData;
        const assetPath = `bundle/${mediaFile.encryptedPath}`;
        try {
          encryptedData = await RNFS.readFileAssets(assetPath, 'base64');
        } catch (e) {
          const sourcePathIOS = `${RNFS.MainBundlePath}/bundle/${mediaFile.encryptedPath}`;
          const existsIOS = await RNFS.exists(sourcePathIOS);
          if (!existsIOS) {
            console.warn(`Embedded media file not found: ${assetPath}`);
            continue;
          }
          encryptedData = await RNFS.readFile(sourcePathIOS, 'base64');
        }

        // Check if already imported
        const alreadyExists = await SecureStorage.mediaFileExists(mediaFile.id);
        if (alreadyExists) {
          console.log(`Media file ${mediaFile.id} already imported`);
          continue;
        }
        
        // Store in secure storage
        await SecureStorage.storeMediaFile(mediaFile.id, encryptedData);
        importedCount++;
        
        console.log(`Imported embedded media file: ${mediaFile.fileName}`);
      } catch (error) {
        console.error(`Failed to import embedded media file ${mediaFile.id}:`, error);
      }
    }

    console.log(`Imported ${importedCount} embedded media files`);
    return importedCount;
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
