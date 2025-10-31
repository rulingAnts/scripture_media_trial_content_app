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
 * @param {Object} options.playlistLimits - Playlist-level playback limits
 * @param {string} options.expirationDate - Optional expiration date (ISO 8601)
 * @returns {Object} - Bundle configuration object
 */
function createBundleConfig(options) {
  const {
    bundleId,
    allowedDeviceIds = [],
    mediaFiles = [],
    playbackLimits = {},
    playlistLimits = {},
    bundleKey = null,
    integrity = null,
    expirationDate = null
  } = options;

  const defaultLimits = {
    maxPlays: 3,
    resetIntervalMs: 24 * 60 * 60 * 1000, // 24 hours in milliseconds
    minIntervalBetweenPlaysMs: null, // Optional: minimum time between plays
    maxPlaysTotal: null // Optional: absolute lifetime limit
  };

  const defaultPlaylistLimits = {
    maxItemsPerSession: null, // Optional: max unique items from playlist that can be played in a session
    sessionResetIntervalMs: null, // Optional: time window for session reset
    minIntervalBetweenItemsMs: null, // Optional: minimum time between playing different items
    maxTotalItemsPlayed: null, // Optional: lifetime limit on number of unique items played
    expirationDate: null // Optional: playlist-level expiration (can differ from bundle expiration)
  };

  return {
    version: '2.0',
    bundleId,
    createdAt: new Date().toISOString(),
    expirationDate,
    allowedDeviceIds,
    mediaFiles: mediaFiles.map(file => ({
      id: file.id,
      fileName: file.fileName,
      title: file.title || file.fileName,
      type: file.type || 'audio', // audio or video
      encryptedPath: file.encryptedPath,
      checksum: file.checksum,
      playbackLimit: file.playbackLimit || playbackLimits.default || defaultLimits
    })),
    playbackLimits: {
      default: playbackLimits.default || defaultLimits
    },
    playlistLimits: {
      ...defaultPlaylistLimits,
      ...playlistLimits
    },
    bundleKey,
    integrity
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

  // Version 2.0 specific validations
  if (config.version === '2.0') {
    if (!config.bundleKey) {
      errors.push('Bundle key is required for version 2.0');
    }
    if (!config.integrity) {
      errors.push('Integrity hash is required for version 2.0');
    }
  }

  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Verifies bundle integrity
 * @param {Object} config - Bundle configuration
 * @returns {boolean} - True if integrity check passes
 */
function verifyBundleIntegrity(config) {
  if (config.version !== '2.0') {
    return false; // Only version 2.0 supports integrity checking
  }

  if (!config.integrity || !config.bundleKey) {
    return false;
  }

  // Create expected integrity hash
  const crypto = require('crypto');
  const expectedHash = crypto.createHash('sha256').update(JSON.stringify({
    bundleId: config.bundleId,
    allowedDeviceIds: config.allowedDeviceIds,
    mediaFiles: config.mediaFiles,
    playbackLimits: config.playbackLimits,
    playlistLimits: config.playlistLimits
  })).digest('hex');

  return expectedHash === config.integrity;
}

module.exports = {
  createBundleConfig,
  validateBundleConfig,
  verifyBundleIntegrity
};
