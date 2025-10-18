import RNFS from 'react-native-fs';
import { encrypt, decrypt } from '@scripture-media/shared';
import DeviceBinding from './DeviceBinding';

/**
 * Handles secure storage and encryption of media files
 */
class SecureStorage {
  constructor() {
    this.basePath = `${RNFS.DocumentDirectoryPath}/secure_media`;
  }

  /**
   * Initializes secure storage directory
   */
  async initialize() {
    try {
      const exists = await RNFS.exists(this.basePath);
      if (!exists) {
        await RNFS.mkdir(this.basePath);
      }
    } catch (error) {
      console.error('Failed to initialize secure storage:', error);
      throw error;
    }
  }

  /**
   * Stores an encrypted media file
   * @param {string} mediaId - The media file ID
   * @param {string} encryptedData - The encrypted file data
   * @returns {Promise<string>} - Path to the stored file
   */
  async storeMediaFile(mediaId, encryptedData) {
    await this.initialize();
    
    const filePath = `${this.basePath}/${mediaId}.enc`;
    
    try {
      // Store the encrypted data
      await RNFS.writeFile(filePath, encryptedData, 'base64');
      
      return filePath;
    } catch (error) {
      console.error('Failed to store media file:', error);
      throw error;
    }
  }

  /**
   * Retrieves and decrypts a media file
   * @param {string} mediaId - The media file ID
   * @returns {Promise<string>} - Temporary path to the decrypted file
   */
  async retrieveMediaFile(mediaId) {
    const encryptedPath = `${this.basePath}/${mediaId}.enc`;
    const tempPath = `${RNFS.CachesDirectoryPath}/${mediaId}_temp`;
    
    try {
      // Check if encrypted file exists
      const exists = await RNFS.exists(encryptedPath);
      if (!exists) {
        throw new Error(`Media file not found: ${mediaId}`);
      }

      // Read encrypted data
      const encryptedData = await RNFS.readFile(encryptedPath, 'base64');
      
      // Get device key for decryption
      const deviceKey = await DeviceBinding.getDeviceKey();
      
      // Decrypt the data
      const decryptedData = decrypt(encryptedData, deviceKey);
      
      // Write to temporary cache location
      await RNFS.writeFile(tempPath, decryptedData, 'base64');
      
      return tempPath;
    } catch (error) {
      console.error('Failed to retrieve media file:', error);
      throw error;
    }
  }

  /**
   * Clears temporary decrypted files
   */
  async clearTempFiles() {
    try {
      const files = await RNFS.readDir(RNFS.CachesDirectoryPath);
      const tempFiles = files.filter(file => file.name.endsWith('_temp'));
      
      for (const file of tempFiles) {
        await RNFS.unlink(file.path);
      }
    } catch (error) {
      console.error('Failed to clear temp files:', error);
    }
  }

  /**
   * Checks if a media file exists
   * @param {string} mediaId - The media file ID
   * @returns {Promise<boolean>} - True if file exists
   */
  async mediaFileExists(mediaId) {
    const filePath = `${this.basePath}/${mediaId}.enc`;
    return await RNFS.exists(filePath);
  }

  /**
   * Deletes a media file
   * @param {string} mediaId - The media file ID
   */
  async deleteMediaFile(mediaId) {
    const filePath = `${this.basePath}/${mediaId}.enc`;
    
    try {
      const exists = await RNFS.exists(filePath);
      if (exists) {
        await RNFS.unlink(filePath);
      }
    } catch (error) {
      console.error('Failed to delete media file:', error);
      throw error;
    }
  }
}

export default new SecureStorage();
