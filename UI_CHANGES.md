# Desktop App UI Changes

## New Playback Limits Section

The desktop bundler app now includes comprehensive playback limit controls:

### Section: Playback Limits

```
┌─────────────────────────────────────────────────────────────┐
│ Playback Limits                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Maximum Plays per Reset Period *                           │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [3]                                                     │ │
│ └─────────────────────────────────────────────────────────┘ │
│ Number of times media can be played before waiting for reset│
│                                                             │
│ Reset Interval *                                            │
│ ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│ │ [0]      │  │ [24]     │  │ [0]      │                  │
│ │ Days     │  │ Hours    │  │ Minutes  │                  │
│ └──────────┘  └──────────┘  └──────────┘                  │
│                                                             │
│ Minimum Interval Between Plays (Optional)                  │
│ ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│ │ [0]      │  │ [0]      │  │ [0]      │                  │
│ │ Days     │  │ Hours    │  │ Minutes  │                  │
│ └──────────┘  └──────────┘  └──────────┘                  │
│ Required waiting time between each play (leave at 0 for no │
│ minimum)                                                    │
│                                                             │
│ Maximum Total Plays Ever (Optional)                        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │                                                         │ │
│ └─────────────────────────────────────────────────────────┘ │
│ Leave empty for no limit                                   │
│ Absolute lifetime limit - media becomes permanently locked │
│ after this many plays                                      │
│                                                             │
│ Bundle Expiration Date & Time (Optional)                   │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [Date/Time Picker]                                      │ │
│ └─────────────────────────────────────────────────────────┘ │
│ Bundle becomes permanently locked after this date/time     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Example Configurations

### Configuration 1: Quick Trial (3 Days)
```
Maximum Plays per Reset Period: 3
Reset Interval: 0 days, 24 hours, 0 minutes
Minimum Interval Between Plays: 0 days, 0 hours, 15 minutes
Maximum Total Plays Ever: 6
Bundle Expiration: [3 days from now]

Result: User gets 3 plays per day for 2 days (6 total), 
        with 15 minutes between each play
```

### Configuration 2: Extended Review (30 Days)
```
Maximum Plays per Reset Period: 5
Reset Interval: 0 days, 12 hours, 0 minutes
Minimum Interval Between Plays: (empty - no minimum)
Maximum Total Plays Ever: (empty - unlimited)
Bundle Expiration: [30 days from now]

Result: User gets 5 plays every 12 hours for 30 days, 
        no waiting between plays
```

### Configuration 3: Strict Limited Access
```
Maximum Plays per Reset Period: 2
Reset Interval: 1 day, 0 hours, 0 minutes
Minimum Interval Between Plays: 0 days, 1 hour, 0 minutes
Maximum Total Plays Ever: 10
Bundle Expiration: [60 days from now]

Result: User can play twice per day, must wait 1 hour between 
        plays, max 10 plays total ever (5 days worth)
```

## Media List Display

When media files are added, they show their limit configuration:

```
┌──────────────────────────────────────────────────────────────┐
│ Luke_Chapter_01.mp3                                          │
│ AUDIO • 5.42 MB • Max plays: 3 • Reset: 1d • Interval: 15m  │
│ • Max total: 6                                    [Remove]   │
├──────────────────────────────────────────────────────────────┤
│ Luke_Chapter_02.mp3                                          │
│ AUDIO • 4.89 MB • Max plays: 5 • Reset: 12h • Interval:     │
│ None • No lifetime limit                          [Remove]   │
└──────────────────────────────────────────────────────────────┘
```

## Visual Improvements

### Before (Old Version):
- Simple "hours" input for reset interval
- Only two fields total
- No expiration support
- No interval enforcement

### After (New Version):
- Days/Hours/Minutes for all time settings
- Seven total configuration options
- Full expiration support with date/time picker
- Comprehensive limit controls
- Detailed display in media list

## User Experience Flow

1. **Set Default Limits**: User configures the default playback limits
2. **Add Media Files**: Each file inherits the default limits
3. **Review**: Media list shows all limits clearly
4. **Create Bundle**: Bundle is created with all limit data encrypted
5. **Distribute**: Users receive bundle with enforced limits

## Mobile App Display (Reference)

The mobile app shows limits for each media file:

```
┌──────────────────────────────────────────────────────────────┐
│ 🎵 Luke_Chapter_01.mp3                                       │
│ 2 / 3 plays left • resets in 8h 23m • 4 / 6 total    [▶]    │
├──────────────────────────────────────────────────────────────┤
│ 🎵 Luke_Chapter_02.mp3                                       │
│ Must wait 12 minutes between plays.                  [🔒]   │
├──────────────────────────────────────────────────────────────┤
│ 🎵 Luke_Chapter_03.mp3                                       │
│ Locked: Lifetime limit reached                       [🔒]   │
└──────────────────────────────────────────────────────────────┘
```

## Key UI/UX Features

### Clear Labeling
- Each field has descriptive label
- Help text explains what each limit does
- Optional fields clearly marked

### Flexible Input
- Time fields accept 0 (disabled)
- Empty fields = no limit
- Validation prevents invalid combinations

### Visual Feedback
- Media list shows parsed limits
- Time values formatted (1d, 12h, 15m)
- Clear indication of limits vs. no limits

### Error Prevention
- Required fields marked with *
- Validation before bundle creation
- Clear error messages

## Technical Notes

### HTML Structure
- Uses grid layout for time inputs
- Semantic HTML5 form elements
- Accessible datetime-local picker

### JavaScript Validation
- Converts time units to milliseconds
- Validates minimum values
- Checks for future dates on expiration

### Data Flow
```
UI Inputs → Renderer.js → Main.js → Bundle Config → .smbundle file
```

All changes maintain the existing UI aesthetic and user experience patterns.
