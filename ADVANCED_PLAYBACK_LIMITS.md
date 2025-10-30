# Advanced Playback Limits - User Guide

This guide explains the advanced playback limit features added to the Scripture Media Trial Content App.

## Overview

The app supports two levels of playback restrictions:

### Per-File Limits
Control individual media file playback with four types of restrictions:

1. **Windowed Play Limits** - Maximum plays within a time window (existing feature, now with flexible time units)
2. **Minimum Interval Between Plays** - Required waiting period between successive plays
3. **Total Play Limit** - Absolute lifetime limit on number of plays
4. **Expiration Date** - Date/time after which bundle becomes permanently locked

### Playlist-Level Limits (NEW)
Control overall usage across all files in the bundle. See [PLAYLIST_LIMITS.md](./PLAYLIST_LIMITS.md) for complete documentation:

1. **Max Items Per Session** - Limit unique files that can be played in a session
2. **Session Reset Interval** - Time window for session-based limits
3. **Minimum Interval Between Items** - Required wait time between different files
4. **Max Total Items Played** - Lifetime limit on unique files played
5. **Playlist Expiration** - Separate expiration date for playlist access

**Both levels work together - the most restrictive limit always applies.**

---

## Per-File Limit Details

### 1. Windowed Play Limits (Enhanced)

**What it does:** Limits how many times media can be played within a rolling time window.

**Desktop UI:**
- **Maximum Plays per Reset Period**: Number of times media can be played before waiting for reset
- **Reset Interval**: Time window in Days, Hours, and Minutes

**Example:**
- Max plays: 3
- Reset interval: 1 day, 0 hours, 0 minutes
- Result: User can play media 3 times per 24-hour period

**Changes from previous version:**
- Previously only supported hours, now supports days, hours, and minutes
- Stored internally as milliseconds for precision

### 2. Minimum Interval Between Plays (NEW)

**What it does:** Enforces a required waiting period between each individual play.

**Desktop UI:**
- **Minimum Interval Between Plays**: Days, Hours, and Minutes (optional)
- Set all to 0 to disable this limit

**Example:**
- Minimum interval: 0 days, 0 hours, 5 minutes
- Result: User must wait at least 5 minutes after finishing a play before starting it again

**Use cases:**
- Prevent rapid repeated plays
- Prevent the user being able to memorize content that is not yet consultant approved.
- Combine with windowed limits (e.g., 3 plays per day, but 15 minutes between each)

### 3. Total Play Limit (NEW)

**What it does:** Sets an absolute maximum number of times media can ever be played.

**Desktop UI:**
- **Maximum Total Plays Ever**: Number (optional)
- Leave empty for no lifetime limit

**Example:**
- Max total: 10
- Result: After 10 total plays (across all time), media becomes permanently locked

**Use cases:**
- Trial content with absolute usage limits
- Ensuring content isn't overused beyond intended scope
- Permanent expiration after specific number of uses

**Important:** This is a permanent lock. Once reached, the media cannot be played again, even across different time windows.

### 4. Expiration Date (NEW)

**What it does:** Makes the entire bundle permanently locked after a specific date/time.

**Desktop UI:**
- **Bundle Expiration Date & Time**: Date/time picker (optional)
- Defaults to midnight if only date is selected

**Example:**
- Expiration: December 31, 2024, 11:59 PM
- Result: Bundle works normally until that date/time, then becomes permanently locked

**Tamper Protection:**
- The app detects if the user sets their device clock backward
- If tampering is detected, bundle becomes permanently locked
- This prevents users from circumventing expiration by changing system time

**Use cases:**
- Time-limited trial periods
- Seasonal content
- Content that should not be accessed after a certain date

## Combining Limits

All four limit types can be used together. The most restrictive limit applies.

### Example 1: Trial Content
```
Max plays per reset: 3
Reset interval: 1 day
Minimum interval: 15 minutes
Max total plays: 6
Expiration: January 31, 2025

Result:
- User can play 3 times per day
- Must wait 15 minutes between each play
- Can only play 6 times total ever (2 days worth)
- Everything stops working after January 31, 2025
```

### Example 2: Consultant Review
```
Max plays per reset: 5
Reset interval: 12 hours
Minimum interval: None (0)
Max total plays: None (unlimited)
Expiration: March 15, 2025

Result:
- User can play 5 times per 12 hours
- No waiting between plays
- No lifetime limit
- Must complete review before March 15, 2025
```

## Mobile App Display

The mobile app shows the current status for each media file:

**When media is available:**
- "3 / 5 plays left · resets in 8h 23m · 7 / 10 total"
- Shows: windowed plays remaining, reset time, total plays remaining

**When blocked by interval:**
- "Must wait 12 minutes between plays."

**When blocked by windowed limit:**
- "Play limit reached. Resets in 2h 15m"

**When permanently locked:**
- "Locked: Lifetime limit reached"
- "Locked: Bundle expired"
- "Locked: Time tampering detected"

## Technical Details

### Time Storage
- All time intervals stored as milliseconds internally
- UI accepts days, hours, minutes for user convenience
- Conversion: `(days × 86400000) + (hours × 3600000) + (minutes × 60000)`

### Tamper Detection
- App tracks last known system time
- If current time < last known time, tampering is detected
- Results in permanent lock of entire bundle
- Persists across app restarts

### Data Persistence
Mobile app tracks:
- `playsUsed`: Plays within current window
- `playsTotal`: Total plays ever
- `lastPlay`: Timestamp of last play
- `playWindowStart`: Start of current window
- `lastKnownTime`: Last verified system time

### Legacy Support
The mobile app supports both old and new formats:
- Old: `resetIntervalHours` (number)
- New: `resetIntervalMs` (number)
- If `resetIntervalMs` is present, it takes precedence

## Creating Bundles with New Limits

1. Open the Desktop Bundler app
2. Configure Bundle Information (name, device IDs)
3. Set Playback Limits:
   - Set max plays per reset period
   - Set reset interval (days, hours, minutes)
   - Optionally set minimum interval between plays
   - Optionally set maximum total plays
   - Optionally set expiration date
4. Add media files (they inherit the default limits)
5. Create bundle

The bundle file (.smbundle) contains all the limit information encrypted and tamper-protected.

## Best Practices

1. **Start Simple**: Don't use all limits at once unless needed
2. **Test First**: Create a test bundle and verify limits work as expected
3. **Document Limits**: Tell reviewers what limits are in place
4. **Plan for Expiration**: Set expiration dates with buffer time
5. **Consider Use Cases**:
   - Quick review: High plays, short window, short expiration
   - Careful study: Moderate plays, longer window, no total limit
   - Limited trial: Low total plays, expiration date

## Troubleshooting

**"Time tampering detected"**
- User changed device clock backward
- Bundle is permanently locked
- Cannot be unlocked - user needs new bundle

**"Bundle expired"**
- Current date/time is past expiration
- Bundle is permanently locked
- User needs new bundle with later expiration

**"Lifetime limit reached"**
- Total plays exceeded maxPlaysTotal
- Permanently locked
- User needs new bundle

**"Must wait X minutes between plays"**
- minIntervalBetweenPlaysMs not elapsed
- Temporary - wait the specified time
- Time remaining shown in message

## Migration from Old Format

**No backward compatibility needed** - Per user request, old bundles do not need to work with new app version.

All new bundles created will use the new format (version 2.0) with:
- `resetIntervalMs` instead of `resetIntervalHours`
- Optional `minIntervalBetweenPlaysMs`
- Optional `maxPlaysTotal`
- Optional `expirationDate` on bundle level

The mobile app can still read old format for testing purposes (converts `resetIntervalHours` to milliseconds), but creation of old format is not supported.
