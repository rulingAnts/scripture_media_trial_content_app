/**
 * Tracks media playback and enforces limits
 */

class PlaybackTracker {
  constructor(storage) {
    this.storage = storage; // Storage interface for persisting playback data
  }

  /**
   * Gets the playback history for a media file
   * @param {string} mediaId - The media file ID
   * @returns {Object} - Playback history
   */
  async getPlaybackHistory(mediaId) {
    const key = `playback_${mediaId}`;
    const history = await this.storage.getItem(key);
    
    if (!history) {
      return {
        plays: [],
        count: 0
      };
    }

    return JSON.parse(history);
  }

  /**
   * Records a playback event
   * @param {string} mediaId - The media file ID
   * @returns {Object} - Updated playback history
   */
  async recordPlayback(mediaId) {
    const history = await this.getPlaybackHistory(mediaId);
    const now = new Date().toISOString();
    
    history.plays.push(now);
    history.count = history.plays.length;

    const key = `playback_${mediaId}`;
    await this.storage.setItem(key, JSON.stringify(history));

    return history;
  }

  /**
   * Checks if a media file can be played based on limits
   * @param {string} mediaId - The media file ID
   * @param {Object} limits - Playback limits configuration
   * @returns {Object} - Result with canPlay flag and reason
   */
  async canPlay(mediaId, limits) {
    const { maxPlays, resetIntervalHours } = limits;
    const history = await this.getPlaybackHistory(mediaId);

    if (history.plays.length === 0) {
      return {
        canPlay: true,
        remainingPlays: maxPlays,
        nextResetTime: null
      };
    }

    // Filter plays within the reset interval
    const now = new Date();
    const resetIntervalMs = resetIntervalHours * 60 * 60 * 1000;
    const cutoffTime = new Date(now.getTime() - resetIntervalMs);

    const recentPlays = history.plays.filter(playTime => {
      return new Date(playTime) > cutoffTime;
    });

    const remainingPlays = Math.max(0, maxPlays - recentPlays.length);

    if (recentPlays.length >= maxPlays) {
      // Find the oldest play in the recent window to determine next reset
      const oldestRecentPlay = new Date(recentPlays[0]);
      const nextResetTime = new Date(oldestRecentPlay.getTime() + resetIntervalMs);

      return {
        canPlay: false,
        remainingPlays: 0,
        nextResetTime: nextResetTime.toISOString(),
        reason: `Maximum plays (${maxPlays}) reached. Next play available at ${nextResetTime.toLocaleString()}`
      };
    }

    // Calculate next reset time based on the oldest recent play
    const oldestRecentPlay = recentPlays.length > 0 ? new Date(recentPlays[0]) : null;
    const nextResetTime = oldestRecentPlay 
      ? new Date(oldestRecentPlay.getTime() + resetIntervalMs).toISOString()
      : null;

    return {
      canPlay: true,
      remainingPlays,
      nextResetTime
    };
  }

  /**
   * Clears old playback records that are outside the reset interval
   * @param {string} mediaId - The media file ID
   * @param {number} resetIntervalHours - The reset interval in hours
   */
  async cleanupOldRecords(mediaId, resetIntervalHours) {
    const history = await this.getPlaybackHistory(mediaId);
    const now = new Date();
    const resetIntervalMs = resetIntervalHours * 60 * 60 * 1000;
    const cutoffTime = new Date(now.getTime() - resetIntervalMs);

    const recentPlays = history.plays.filter(playTime => {
      return new Date(playTime) > cutoffTime;
    });

    history.plays = recentPlays;
    history.count = recentPlays.length;

    const key = `playback_${mediaId}`;
    await this.storage.setItem(key, JSON.stringify(history));

    return history;
  }
}

module.exports = PlaybackTracker;
