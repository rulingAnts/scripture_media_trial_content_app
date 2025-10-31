# Known Issues

Updated: 2025-10-31

## Mobile: Auto fullscreen toggle inconsistent; fullscreen button broken

- Component: `mobile-app`
- Status: Open
- Priority: Medium
- Labels: mobile, bug, fullscreen, rotation

### Summary
- Back-and-forth automatic fullscreen/non-fullscreen based on device orientation (portrait/landscape) is not yet fully functional.
- The "Full screen" button is currently broken.

### Expected behavior
- When rotating the device to landscape, the player should reliably enter fullscreen.
- When rotating back to portrait, it should exit fullscreen.
- The UI "Full screen" button should explicitly enter fullscreen regardless of orientation.

### Actual behavior
- Rotation sometimes does not trigger the expected enter/exit fullscreen behavior.
- The explicit "Full screen" button no longer enters fullscreen.

### Steps to reproduce
1. Open the mobile app and start playing any video.
2. Rotate the device to landscape. Observe whether it enters fullscreen.
3. Rotate back to portrait. Observe whether it exits fullscreen.
4. Tap the "Full screen" button. Observe that it does not enter fullscreen.

### Environment
- Platform: Mobile app (Flutter)
- Affected devices: Likely both Android and iOS (needs full sweep)
- Related modules: Video player, SystemChrome UI/orientation, fullscreen toggle logic

### Suspected causes
- Orientation listener debounce and `_inFullscreen` guard may conflict, preventing re-entry.
- Orientation lock transitions (via `SystemChrome.setPreferredOrientations`) may race with route pushes for fullscreen page.
- "Full screen" button pathway might be gated by the same guard or not updating internal state after refactor.

### Proposed direction
- Unify orientation handling: a single source of truth for fullscreen state; ensure idempotent enter/exit.
- Review `_goFullscreen()` and `_FullscreenVideoPage` for guards that prevent re-entry when already toggled once.
- Ensure explicit button bypasses orientation gating and calls enter-fullscreen flow directly (with safe guards).
- Verify `SystemChrome` calls (UI overlays and orientations) are paired and restored on pop.
- Add a short debounce (e.g., 300–500ms) on rotation to avoid flapping but not block subsequent transitions.
- Instrument logs around orientation changes and fullscreen transitions for diagnosis.

### Acceptance criteria
- Rotating to landscape consistently enters fullscreen within 500 ms.
- Rotating to portrait consistently exits fullscreen within 500 ms.
- The "Full screen" button enters fullscreen even when device is in portrait.
- No double charges or playback counter side effects are introduced by the transition.
- Works on both Android and iOS; manual smoke verified.

### Notes
- This is a follow-up task to the initial fullscreen/auto-rotate feature. Timeboxed for later iteration.

---

## GitHub issue (ready to paste)

Title:

Mobile: Auto fullscreen rotation inconsistent; fullscreen button not working

Body:

- Component: mobile-app (Flutter)
- Priority: Medium | Labels: mobile, bug, fullscreen, rotation

Summary:
- Back-and-forth automatic fullscreen/non-fullscreen behavior based on orientation is inconsistent.
- The "Full screen" button no longer works.

Expected:
- Landscape rotation auto-enters fullscreen; portrait rotation exits.
- Button explicitly enters fullscreen.

Actual:
- Rotation sometimes does not trigger expected transitions.
- Button fails to enter fullscreen.

Repro:
1) Play a video; 2) Rotate to landscape; 3) Rotate to portrait; 4) Tap "Full screen".

Environment:
- Android and iOS; video_player + SystemChrome.

Suspected causes:
- Debounce/guard interplay; orientation lock race; stale state.

Proposed direction:
- Single source of truth for fullscreen state; idempotent enter/exit; review `_goFullscreen()`, `_FullscreenVideoPage`; verify `SystemChrome` pairings; add small debounce; add logging.

Acceptance criteria:
- Consistent rotation-based toggling; button works; no counter side effects; both platforms.

