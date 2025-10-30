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
        count: 0,
        totalPlays: 0,
        lastPlayTime: null
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
    history.totalPlays = (history.totalPlays || 0) + 1;
    history.lastPlayTime = now;

    const key = `playback_${mediaId}`;
    await this.storage.setItem(key, JSON.stringify(history));

    return history;
  }

  /**
   * Checks if a media file can be played based on limits
   * @param {string} mediaId - The media file ID
   * @param {Object} limits - Playback limits configuration
   * @param {string} bundleExpirationDate - Optional bundle expiration date (ISO 8601)
   * @returns {Object} - Result with canPlay flag and reason
   */
  async canPlay(mediaId, limits, bundleExpirationDate = null) {
    const now = new Date();
    
    // Check for time tampering - if lastKnownTime exists and is in the future
    const lastKnownTimeKey = 'lastKnownTime';
    const lastKnownTimeStr = await this.storage.getItem(lastKnownTimeKey);
    if (lastKnownTimeStr) {
      const lastKnownTime = new Date(lastKnownTimeStr);
      if (now < lastKnownTime) {
        return {
          canPlay: false,
          remainingPlays: 0,
          nextResetTime: null,
          reason: 'Time tampering detected. Bundle is permanently locked.',
          permanentlyLocked: true
        };
      }
    }
    await this.storage.setItem(lastKnownTimeKey, now.toISOString());

    // Check bundle expiration date
    if (bundleExpirationDate) {
      const expirationDate = new Date(bundleExpirationDate);
      if (now >= expirationDate) {
        return {
          canPlay: false,
          remainingPlays: 0,
          nextResetTime: null,
          reason: `Bundle expired on ${expirationDate.toLocaleString()}`,
          permanentlyLocked: true
        };
      }
    }

    const { 
      maxPlays, 
      resetIntervalMs, 
      minIntervalBetweenPlaysMs, 
      maxPlaysTotal,
      // Legacy support
      resetIntervalHours
    } = limits;

    // Convert legacy hours to milliseconds if needed
    const resetMs = resetIntervalMs || (resetIntervalHours ? resetIntervalHours * 60 * 60 * 1000 : 24 * 60 * 60 * 1000);
    
    const history = await this.getPlaybackHistory(mediaId);

    // Check total plays limit (absolute lifetime limit)
    if (maxPlaysTotal !== null && maxPlaysTotal !== undefined) {
      if (history.totalPlays >= maxPlaysTotal) {
        return {
          canPlay: false,
          remainingPlays: 0,
          nextResetTime: null,
          reason: `Maximum lifetime plays (${maxPlaysTotal}) reached. Permanently locked.`,
          permanentlyLocked: true
        };
      }
    }

    // Check minimum interval between plays
    if (minIntervalBetweenPlaysMs && history.lastPlayTime) {
      const lastPlay = new Date(history.lastPlayTime);
      const timeSinceLastPlay = now.getTime() - lastPlay.getTime();
      
      if (timeSinceLastPlay < minIntervalBetweenPlaysMs) {
        const nextAvailableTime = new Date(lastPlay.getTime() + minIntervalBetweenPlaysMs);
        const remainingMs = minIntervalBetweenPlaysMs - timeSinceLastPlay;
        const remainingMinutes = Math.ceil(remainingMs / (60 * 1000));
        
        return {
          canPlay: false,
          remainingPlays: maxPlays - history.plays.filter(p => {
            return new Date(p) > new Date(now.getTime() - resetMs);
          }).length,
          nextResetTime: nextAvailableTime.toISOString(),
          reason: `Must wait ${remainingMinutes} minute(s) between plays. Next play available at ${nextAvailableTime.toLocaleString()}`
        };
      }
    }

    if (history.plays.length === 0) {
      return {
        canPlay: true,
        remainingPlays: maxPlays,
        remainingTotalPlays: maxPlaysTotal ? maxPlaysTotal - history.totalPlays : null,
        nextResetTime: null
      };
    }

    // Filter plays within the reset interval
    const cutoffTime = new Date(now.getTime() - resetMs);

    const recentPlays = history.plays.filter(playTime => {
      return new Date(playTime) > cutoffTime;
    });

    const remainingPlays = Math.max(0, maxPlays - recentPlays.length);

    if (recentPlays.length >= maxPlays) {
      // Find the oldest play in the recent window to determine next reset
      const oldestRecentPlay = new Date(recentPlays[0]);
      const nextResetTime = new Date(oldestRecentPlay.getTime() + resetMs);

      return {
        canPlay: false,
        remainingPlays: 0,
        remainingTotalPlays: maxPlaysTotal ? maxPlaysTotal - history.totalPlays : null,
        nextResetTime: nextResetTime.toISOString(),
        reason: `Maximum plays (${maxPlays}) reached. Next play available at ${nextResetTime.toLocaleString()}`
      };
    }

    // Calculate next reset time based on the oldest recent play
    const oldestRecentPlay = recentPlays.length > 0 ? new Date(recentPlays[0]) : null;
    const nextResetTime = oldestRecentPlay 
      ? new Date(oldestRecentPlay.getTime() + resetMs).toISOString()
      : null;

    return {
      canPlay: true,
      remainingPlays,
      remainingTotalPlays: maxPlaysTotal ? maxPlaysTotal - history.totalPlays : null,
      nextResetTime
    };
  }

  /**
   * Clears old playback records that are outside the reset interval
   * @param {string} mediaId - The media file ID
   * @param {number} resetIntervalMs - The reset interval in milliseconds
   */
  async cleanupOldRecords(mediaId, resetIntervalMs) {
    const history = await this.getPlaybackHistory(mediaId);
    const now = new Date();
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
