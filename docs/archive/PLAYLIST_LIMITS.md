# Playlist-Level Playback Limits

This document describes the playlist-level playback limits feature, which allows content creators to restrict how users interact with multiple media files in a bundle beyond the existing per-file limits.

## Overview

While per-file limits control individual media playback (e.g., "play this file 3 times per day"), playlist-level limits control overall usage across **all files** in a bundle (e.g., "play only 3 different files per session").

Both types of limits work together, and the most restrictive limit always applies.

## Use Cases

### Example 1: Controlled Review Sessions
**Scenario**: You want reviewers to listen to a few files at a time, spread out over several days, rather than binge-listening to all content at once.

**Configuration**:
```json
{
  "playlistLimits": {
    "maxItemsPerSession": 3,
    "sessionResetIntervalMs": 86400000,  // 24 hours
    "minIntervalBetweenItemsMs": 300000  // 5 minutes
  }
}
```

**Result**: Users can play 3 different files per day, with at least 5 minutes between each file.

### Example 2: Trial Content with Total Item Limits
**Scenario**: Provide access to a large library but limit the total number of unique files that can be played.

**Configuration**:
```json
{
  "playlistLimits": {
    "maxTotalItemsPlayed": 10,
    "expirationDate": "2025-12-31T23:59:59Z"
  }
}
```

**Result**: Users can play any 10 unique files from the bundle before it becomes permanently locked, and everything expires on Dec 31, 2025.

### Example 3: Gradual Content Exposure
**Scenario**: Prevent memorization by forcing breaks between different files.

**Configuration**:
```json
{
  "playlistLimits": {
    "minIntervalBetweenItemsMs": 3600000  // 1 hour
  }
}
```

**Result**: Users must wait 1 hour between playing different files (but can replay the same file within that hour if per-file limits allow).

## Playlist Limit Types

### 1. Max Items Per Session (`maxItemsPerSession`)

**What it does**: Limits how many **unique** files can be played within a session.

**Type**: `number` (integer) or `null`

**Example**: `"maxItemsPerSession": 3`

**Behavior**:
- Tracks unique files played in the current session
- Once limit is reached, no new files can be played until session resets
- Already-played files in the session can still be replayed (subject to per-file limits)
- Requires `sessionResetIntervalMs` to be set for automatic reset

**User Experience**:
- Blocked message: "Session limit reached: 3 items per session. Resets in 5h 30m"

---

### 2. Session Reset Interval (`sessionResetIntervalMs`)

**What it does**: Defines the time window for a session.

**Type**: `number` (milliseconds) or `null`

**Example**: `"sessionResetIntervalMs": 43200000` (12 hours)

**Behavior**:
- Session starts when the first file is played
- After the interval elapses, the session resets and the played-items counter clears
- If `null`, session never auto-resets (only manual app restart)

**Related**: Works with `maxItemsPerSession`

---

### 3. Minimum Interval Between Items (`minIntervalBetweenItemsMs`)

**What it does**: Enforces a waiting period between playing **different** files.

**Type**: `number` (milliseconds) or `null`

**Example**: `"minIntervalBetweenItemsMs": 900000` (15 minutes)

**Behavior**:
- Tracks the timestamp of the last item played
- When user tries to play a different file, checks if enough time has elapsed
- Does NOT apply when replaying the same file (that's controlled by per-file `minIntervalBetweenPlaysMs`)

**User Experience**:
- Blocked message: "Must wait 12 minutes between playing different items."

---

### 4. Max Total Items Played (`maxTotalItemsPlayed`)

**What it does**: Permanently limits how many unique files can **ever** be played from the bundle.

**Type**: `number` (integer) or `null`

**Example**: `"maxTotalItemsPlayed": 5`

**Behavior**:
- Tracks all unique files ever played (persists across sessions and app restarts)
- Once limit is reached, no new files can be played, ever
- Files already played can still be replayed (subject to per-file limits)
- **This is a permanent lock** - cannot be undone

**User Experience**:
- Blocked message: "Maximum unique items (5) from playlist already played. Permanently locked."

---

### 5. Playlist Expiration Date (`expirationDate`)

**What it does**: Makes the entire playlist permanently locked after a specific date/time.

**Type**: `string` (ISO 8601 date) or `null`

**Example**: `"expirationDate": "2025-06-30T23:59:59Z"`

**Behavior**:
- Can differ from the bundle's overall `expirationDate`
- If set, no files can be played after this date (permanent lock)
- Works in conjunction with bundle expiration (earliest date applies)

**User Experience**:
- Blocked message: "Playlist expired on Jun 30, 2025. Permanently locked."

---

## How Playlist and Per-File Limits Interact

Both limit types are checked independently, and the **most restrictive** limit blocks playback.

### Example Scenario

**Configuration**:
```json
{
  "playlistLimits": {
    "maxItemsPerSession": 3,
    "sessionResetIntervalMs": 86400000,  // 24 hours
    "minIntervalBetweenItemsMs": 600000  // 10 minutes
  },
  "playbackLimits": {
    "default": {
      "maxPlays": 2,
      "resetIntervalMs": 43200000,  // 12 hours
      "minIntervalBetweenPlaysMs": 300000  // 5 minutes
    }
  }
}
```

**User Experience**:

1. **First file (File A)**: ✅ Plays successfully
   - Per-file: 0/2 plays used
   - Playlist: 1/3 items in session

2. **Immediately play File A again**: ❌ Blocked
   - Reason: Per-file min interval (5 minutes) not met

3. **5 minutes later, play File A again**: ✅ Plays successfully
   - Per-file: 1/2 plays used
   - Playlist: Still 1/3 items (same file)

4. **Immediately play File B**: ❌ Blocked
   - Reason: Playlist min interval between items (10 minutes) not met

5. **10 minutes later, play File B**: ✅ Plays successfully
   - Per-file: 0/2 plays used (File B)
   - Playlist: 2/3 items in session

6. **Continue playing Files C, D, etc.**: 
   - Files C: ✅ (after 10 min wait)
   - File D: ❌ Session limit reached (3 items/session)

7. **24 hours later**: Session resets, can play 3 new unique items

## Bundle Schema

Add `playlistLimits` to your bundle configuration:

```json
{
  "version": "2.0",
  "bundleId": "example-bundle-123",
  "playlistLimits": {
    "maxItemsPerSession": 3,
    "sessionResetIntervalMs": 86400000,
    "minIntervalBetweenItemsMs": 600000,
    "maxTotalItemsPlayed": 15,
    "expirationDate": "2025-12-31T23:59:59Z"
  },
  "playbackLimits": {
    "default": {
      "maxPlays": 5,
      "resetIntervalMs": 43200000
    }
  },
  "mediaFiles": [...]
}
```

### Default Values

If `playlistLimits` is omitted or any field is `null`, that limit is not enforced:

```json
{
  "maxItemsPerSession": null,           // No session item limit
  "sessionResetIntervalMs": null,       // No automatic session reset
  "minIntervalBetweenItemsMs": null,    // No wait between items
  "maxTotalItemsPlayed": null,          // No lifetime item limit
  "expirationDate": null                // No playlist expiration
}
```

## Mobile App Behavior

### State Tracking

The mobile app tracks:
- `playlistSession:${bundleId}:items` - List of unique items played in current session
- `playlistSession:${bundleId}:start` - Timestamp when current session started
- `playlistTotal:${bundleId}:items` - List of all unique items ever played (lifetime)
- `playlistLastItemPlay:${bundleId}` - Timestamp of last item played (for inter-item intervals)

### Enforcement Order

When user tries to play a file:

1. **Time tampering check** (bundle-level)
2. **Bundle expiration check** (bundle-level)
3. **Session reset** (automatic, if interval elapsed)
4. **Playlist expiration check**
5. **Total items limit check**
6. **Inter-item interval check**
7. **Session items limit check**
8. **Per-file total plays check**
9. **Per-file min interval check**
10. **Per-file windowed plays check**

### User Feedback

The app shows specific error messages for each limit type:

- "Session limit reached: 3 items per session. Resets in 2h 15m"
- "Maximum unique items (10) from playlist already played. Permanently locked."
- "Must wait 12 minutes between playing different items."
- "Playlist expired on Dec 31, 2024. Permanently locked."

## Best Practices

### 1. Start Simple
Don't use all limits at once. Start with one or two and add more as needed:
```json
{
  "playlistLimits": {
    "maxItemsPerSession": 5,
    "sessionResetIntervalMs": 86400000
  }
}
```

### 2. Match Limits to Use Case

**Quick Review**:
```json
{
  "playlistLimits": {
    "maxItemsPerSession": 10,
    "sessionResetIntervalMs": 3600000,  // 1 hour
    "expirationDate": "2025-01-15T23:59:59Z"
  }
}
```

**Careful Study**:
```json
{
  "playlistLimits": {
    "maxItemsPerSession": 3,
    "sessionResetIntervalMs": 86400000,  // 24 hours
    "minIntervalBetweenItemsMs": 1800000  // 30 minutes
  }
}
```

**Limited Trial**:
```json
{
  "playlistLimits": {
    "maxTotalItemsPlayed": 10,
    "expirationDate": "2025-03-31T23:59:59Z"
  }
}
```

### 3. Coordinate with Per-File Limits

Make sure playlist and per-file limits work together logically:

```json
{
  "playlistLimits": {
    "maxItemsPerSession": 5,  // 5 different files
    "sessionResetIntervalMs": 86400000  // per day
  },
  "playbackLimits": {
    "default": {
      "maxPlays": 3,  // Each file can be played 3 times
      "resetIntervalMs": 86400000  // per day
    }
  }
}
```

**Result**: User can play 5 different files, each up to 3 times, per day = max 15 total plays per day.

### 4. Test Thoroughly

Create test bundles and verify:
- ✅ Session limits reset correctly
- ✅ Lifetime limits are permanent
- ✅ Inter-item intervals work as expected
- ✅ Most restrictive limit applies
- ✅ Error messages are clear

### 5. Document for Users

Tell your users what limits are in place:
- How many items they can play per session
- How long they must wait between items
- When the playlist expires
- Total lifetime limit (if any)

## Migration Notes

- Existing bundles without `playlistLimits` continue to work (no playlist limits applied)
- The feature is backward compatible - old mobile app versions ignore `playlistLimits`
- If you add playlist limits to an existing bundle, users must re-import it (bundles cannot be updated in place)

## Troubleshooting

### "Session limit reached" but user hasn't played that many files

**Cause**: Session hasn't reset yet.

**Solution**: 
- Wait for `sessionResetIntervalMs` to elapse
- Or restart the app (if no auto-reset configured)

### "Maximum unique items from playlist already played"

**Cause**: `maxTotalItemsPlayed` limit reached.

**Solution**: This is permanent. User needs a new bundle to continue.

### Playlist limits not working

**Check**:
1. Is `playlistLimits` in the bundle config?
2. Are the limit values `null` (which disables them)?
3. Is the mobile app version recent enough?

## Technical Details

### Time Units

All time intervals are in **milliseconds**:
- 1 second = 1,000 ms
- 1 minute = 60,000 ms
- 1 hour = 3,600,000 ms
- 1 day = 86,400,000 ms

### Session Lifecycle

1. Session starts: User plays first file
2. `playlistSession:${bundleId}:start` = current timestamp
3. Each unique file played is added to `playlistSession:${bundleId}:items`
4. Session expires: `current time - start time >= sessionResetIntervalMs`
5. On next play attempt, session keys are cleared and reset

### Persistence

- Session data persists across app restarts (until session expires)
- Total items data persists forever
- All data is stored in `SharedPreferences` (mobile app)

## API Reference

### Bundle Configuration

```typescript
interface PlaylistLimits {
  maxItemsPerSession?: number | null;      // Max unique items per session
  sessionResetIntervalMs?: number | null;  // Session window duration (ms)
  minIntervalBetweenItemsMs?: number | null; // Wait time between items (ms)
  maxTotalItemsPlayed?: number | null;     // Lifetime unique items limit
  expirationDate?: string | null;          // ISO 8601 date string
}

interface BundleConfig {
  version: string;
  bundleId: string;
  playlistLimits?: PlaylistLimits;
  playbackLimits: {
    default: PlaybackLimit;
  };
  // ... other fields
}
```

### Mobile App Storage Keys

```
playlistSession:${bundleId}:items       -> List<String> (unique file names)
playlistSession:${bundleId}:start       -> int (milliseconds timestamp)
playlistTotal:${bundleId}:items         -> List<String> (all unique files ever)
playlistLastItemPlay:${bundleId}        -> int (milliseconds timestamp)
```

## See Also

- [ADVANCED_PLAYBACK_LIMITS.md](./ADVANCED_PLAYBACK_LIMITS.md) - Per-file playback limits
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Overall system design
- [shared/src/bundle-schema.js](./shared/src/bundle-schema.js) - Bundle schema implementation
