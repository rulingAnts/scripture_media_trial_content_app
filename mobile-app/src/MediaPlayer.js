import AsyncStorage from '@react-native-async-storage/async-storage';
import { PlaybackTracker } from '@scripture-media/shared';
import BundleManager from './BundleManager';
import SecureStorage from './SecureStorage';

/**
 * Custom storage adapter for AsyncStorage
 */
class AsyncStorageAdapter {
  async getItem(key) {
    return await AsyncStorage.getItem(key);
  }

  async setItem(key, value) {
    await AsyncStorage.setItem(key, value);
  }

  async removeItem(key) {
    await AsyncStorage.removeItem(key);
  }
}

/**
 * Manages media playback with usage tracking and limits
 */
class MediaPlayer {
  constructor() {
    this.tracker = new PlaybackTracker(new AsyncStorageAdapter());
    this.currentMediaId = null;
    this.currentMediaPath = null;
  }

  /**
   * Prepares a media file for playback
   * @param {string} mediaId - The media file ID
   * @returns {Promise<Object>} - Result with path and playback info
   */
  async prepareMedia(mediaId) {
    try {
      // Get media file info from bundle
      const mediaFile = await BundleManager.getMediaFile(mediaId);
      if (!mediaFile) {
        throw new Error(`Media file not found: ${mediaId}`);
      }

      // Check playback limits
      const canPlayResult = await this.tracker.canPlay(mediaId, mediaFile.playbackLimit);
      
      if (!canPlayResult.canPlay) {
        return {
          canPlay: false,
          reason: canPlayResult.reason,
          nextResetTime: canPlayResult.nextResetTime
        };
      }

      // Retrieve and decrypt media file
      const mediaPath = await SecureStorage.retrieveMediaFile(mediaId);
      
      this.currentMediaId = mediaId;
      this.currentMediaPath = mediaPath;

      return {
        canPlay: true,
        mediaPath,
        mediaFile,
        remainingPlays: canPlayResult.remainingPlays,
        nextResetTime: canPlayResult.nextResetTime
      };
    } catch (error) {
      console.error('Failed to prepare media:', error);
      throw error;
    }
  }

  /**
   * Records that playback has started
   * @param {string} mediaId - The media file ID
   */
  async startPlayback(mediaId) {
    try {
      await this.tracker.recordPlayback(mediaId);
      console.log(`Playback started for media: ${mediaId}`);
    } catch (error) {
      console.error('Failed to record playback:', error);
      throw error;
    }
  }

  /**
   * Cleans up after playback ends
   */
  async cleanupPlayback() {
    if (this.currentMediaPath) {
      await SecureStorage.clearTempFiles();
      this.currentMediaPath = null;
      this.currentMediaId = null;
    }
  }

  /**
   * Gets playback statistics for a media file
   * @param {string} mediaId - The media file ID
   * @returns {Promise<Object>} - Playback statistics
   */
  async getPlaybackStats(mediaId) {
    const mediaFile = await BundleManager.getMediaFile(mediaId);
    if (!mediaFile) {
      throw new Error(`Media file not found: ${mediaId}`);
    }

    const history = await this.tracker.getPlaybackHistory(mediaId);
    const canPlayResult = await this.tracker.canPlay(mediaId, mediaFile.playbackLimit);

    return {
      totalPlays: history.count,
      plays: history.plays,
      canPlay: canPlayResult.canPlay,
      remainingPlays: canPlayResult.remainingPlays,
      nextResetTime: canPlayResult.nextResetTime,
      playbackLimit: mediaFile.playbackLimit
    };
  }

  /**
   * Gets playback statistics for all media files
   * @returns {Promise<Object>} - Statistics for all media files
   */
  async getAllPlaybackStats() {
    const mediaFiles = await BundleManager.getMediaFiles();
    const stats = {};

    for (const mediaFile of mediaFiles) {
      try {
        stats[mediaFile.id] = await this.getPlaybackStats(mediaFile.id);
      } catch (error) {
        console.error(`Failed to get stats for ${mediaFile.id}:`, error);
        stats[mediaFile.id] = { error: error.message };
      }
    }

    return stats;
  }
}

export default new MediaPlayer();
