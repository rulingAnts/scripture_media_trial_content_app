# TODO — Playback Limits and Policy Enhancements

These are future enhancements to the bundle policy and playback-limit system. Current app already supports per-media/default max plays with reset windows and anti-bypass controls.

## Playback Limits: Next Iteration
- [ ] Granular per-media play allowance options
  - [ ] Add per-media explicit `maxPlays` override (default already exists) with validation
  - [ ] Support per-bundle and per-media priority rules (media override > bundle default)
- [ ] Inter-play cooldown/intervals
  - [ ] Add configurable `minMinutesBetweenPlays` (cooldown) per-media and default
  - [ ] Enforce at start of playback; show time-remaining message if still cooling down
- [ ] Total plays cap before permanent block
  - [ ] Add `lifetimeMaxPlays` (per-media, optional) after which item is permanently blocked
  - [ ] Persist lifetime counter separate from windowed counters; cannot be reset by intervals
- [ ] Expiration date/time
  - [ ] Add `expiresAt` (ISO 8601 UTC) for bundle and for individual media (media overrides bundle)
  - [ ] Block playback after expiry with clear UI message; hide Play action if desired

## Schema and Bundling
- [ ] Update shared schema (`shared/src/bundle-schema.js`) with new fields and validation
- [ ] Update desktop app to author these fields (UI + validation) and include in `bundle.smb`
- [ ] Maintain backward compatibility (old bundles without fields still work with current defaults)

## Mobile Enforcement
- [ ] Parse and honor new fields in `mobile_app` when importing bundle config
- [ ] Extend play-admission checks (cooldown, lifetime cap, expiry) before starting playback
- [ ] Add user-facing messages: remaining plays, cooldown ETA, lifetime cap reached, expired
- [ ] Ensure persistence keys are versioned/migratable; avoid corrupting existing counters

## UX and Messaging
- [ ] Displays
  - [ ] Plays remaining (windowed + lifetime), cooldown countdown, and expiry date
  - [ ] Optional: Warning banner when within N plays of lifetime cap or N hours of expiry
- [ ] Controls
  - [ ] Disable/gray out Play when blocked, with tooltip/message explaining why

## Edge Cases and Quality
- [ ] Handle timezone/clock skew consistently (store/compare in UTC; avoid device clock bypass when possible)
- [ ] Define window boundaries precisely (e.g., rolling window vs. fixed window start)
- [ ] Natural end near boundary should still charge exactly once
- [ ] Robustness across app restarts/crashes (persist state atomically)

## Testing
- [ ] Unit tests for admission logic (happy path + cooldown + lifetime cap + expiry)
- [ ] Integration tests for import → enforce → UI messages
- [ ] Backward compatibility tests with legacy bundles

## Documentation
- [ ] Update `README.md`/`USAGE.md` with new fields and examples
- [ ] Update `desktop-app/README.md` authoring guide and screenshots
