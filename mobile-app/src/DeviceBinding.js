import DeviceInfo from 'react-native-device-info';
import { generateDeviceKey } from '@scripture-media/shared';

/**
 * Handles device identification and binding
 */
class DeviceBinding {
  constructor() {
    this.deviceId = null;
    this.deviceKey = null;
  }

  /**
   * Initializes device binding
   * @returns {Promise<Object>} - Device information
   */
  async initialize() {
    try {
      // Get unique device identifier
      this.deviceId = await DeviceInfo.getUniqueId();
      
      // Generate device-specific key
      const salt = 'scripture-media-app-2024';
      this.deviceKey = generateDeviceKey(this.deviceId, salt);

      return {
        deviceId: this.deviceId,
        deviceKey: this.deviceKey,
        brand: await DeviceInfo.getBrand(),
        model: await DeviceInfo.getModel(),
        systemVersion: await DeviceInfo.getSystemVersion()
      };
    } catch (error) {
      console.error('Failed to initialize device binding:', error);
      throw error;
    }
  }

  /**
   * Verifies if the current device is allowed to access a bundle
   * @param {Array<string>} allowedDeviceIds - List of allowed device IDs
   * @returns {boolean} - True if device is allowed
   */
  async isDeviceAllowed(allowedDeviceIds) {
    if (!this.deviceId) {
      await this.initialize();
    }

    return allowedDeviceIds.includes(this.deviceId);
  }

  /**
   * Gets the current device ID
   * @returns {Promise<string>} - The device ID
   */
  async getDeviceId() {
    if (!this.deviceId) {
      await this.initialize();
    }
    return this.deviceId;
  }

  /**
   * Gets the current device key
   * @returns {Promise<string>} - The device key
   */
  async getDeviceKey() {
    if (!this.deviceKey) {
      await this.initialize();
    }
    return this.deviceKey;
  }
}

export default new DeviceBinding();
