/**
 * Schema for media bundle configuration
 */

/**
 * Creates a new bundle configuration
 * @param {Object} options - Bundle options
 * @param {string} options.bundleId - Unique bundle identifier
 * @param {Array<string>} options.allowedDeviceIds - List of allowed device IDs
 * @param {Array<Object>} options.mediaFiles - Media files in the bundle
 * @param {Object} options.playbackLimits - Playback limit configuration
 * @returns {Object} - Bundle configuration object
 */
function createBundleConfig(options) {
  const {
    bundleId,
    allowedDeviceIds = [],
    mediaFiles = [],
    playbackLimits = {}
  } = options;

  return {
    version: '1.0',
    bundleId,
    createdAt: new Date().toISOString(),
    allowedDeviceIds,
    mediaFiles: mediaFiles.map(file => ({
      id: file.id,
      fileName: file.fileName,
      title: file.title || file.fileName,
      type: file.type || 'audio', // audio or video
      encryptedPath: file.encryptedPath,
      checksum: file.checksum,
      playbackLimit: file.playbackLimit || playbackLimits.default || {
        maxPlays: 3,
        resetIntervalHours: 24
      }
    })),
    playbackLimits: {
      default: playbackLimits.default || {
        maxPlays: 3,
        resetIntervalHours: 24
      }
    }
  };
}

/**
 * Validates a bundle configuration
 * @param {Object} config - Bundle configuration to validate
 * @returns {Object} - Validation result with isValid and errors
 */
function validateBundleConfig(config) {
  const errors = [];

  if (!config.version) {
    errors.push('Bundle version is required');
  }

  if (!config.bundleId) {
    errors.push('Bundle ID is required');
  }

  if (!Array.isArray(config.allowedDeviceIds) || config.allowedDeviceIds.length === 0) {
    errors.push('At least one allowed device ID is required');
  }

  if (!Array.isArray(config.mediaFiles) || config.mediaFiles.length === 0) {
    errors.push('At least one media file is required');
  }

  if (config.mediaFiles) {
    config.mediaFiles.forEach((file, index) => {
      if (!file.id) {
        errors.push(`Media file at index ${index} is missing id`);
      }
      if (!file.fileName) {
        errors.push(`Media file at index ${index} is missing fileName`);
      }
      if (!file.encryptedPath) {
        errors.push(`Media file at index ${index} is missing encryptedPath`);
      }
    });
  }

  return {
    isValid: errors.length === 0,
    errors
  };
}

module.exports = {
  createBundleConfig,
  validateBundleConfig
};
