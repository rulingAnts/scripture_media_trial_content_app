# Google Play Release Roadmap (Nov 2025)

This roadmap outlines the concrete steps to publish the Android app to Google Play. It’s split into phases you can complete incrementally.

> App package name: `net.iraobi.scripturedemoplayer`

## Phase 0 — Account & prerequisites (0.5–1 day)
- Create/verify a Google Play Console developer account (one-time registration fee)
- Set developer contact email/website
- Create the app entry with the existing package name
- Enroll in Play App Signing (recommended)

Acceptance:
- App entry exists in Play Console
- Play App Signing is enabled

## Phase 1 — Signing & AAB (1–2 hours)
- Generate an upload keystore (store securely)
- Add `keystore.properties` (gitignored) with store/file passwords
- Configure `android/app/build.gradle.kts` for release signing (currently uses debug in release)
- Build a release AAB (choose one path):
  - Preferred (consistent with our APK flow): use Gradle directly
    - `cd mobile_app/android && ./gradlew :app:bundleRelease`
    - Output: `mobile_app/build/app/outputs/bundle/release/app-release.aab`
  - Alternative (if working in your env): `flutter build appbundle`
    - Note: since we rely on a custom script for APKs, Flutter’s AAB build may also be flaky; the Gradle path above is recommended

Acceptance:
- Release AAB builds reproducibly and is ready to upload

## Phase 2 — Privacy & Policies (2–4 hours)
- Draft `PRIVACY_POLICY.md` (no personal data collection; user-initiated file opening/sharing)
- Publish policy (GitHub Pages or your website)
- Complete Play Console Data safety form
- Complete Content rating questionnaire
- Add a support email in the listing

Acceptance:
- Play Console shows policy items completed with no blocking warnings

## Phase 3 — Store listing & assets (2–6 hours)
- Write title, short and long descriptions (concise, localized if desired)
- Create assets:
  - High‑res icon: 512×512 PNG
  - Feature graphic: 1024×500 PNG
  - Screenshots: 2–8 phone screenshots (1080×1920 recommended)
- Choose category (e.g., Tools or Media & Video)

Acceptance:
- Store listing passes asset validations and previews correctly

## Phase 4 — Target SDK & technical checks (1–2 hours)
- Ensure `compileSdk`/`targetSdk` meet Play’s current requirement (API 34/35)
  - If Flutter variables lag, set overrides in Gradle
- Run `flutter analyze` (should be clean)

Acceptance:
- Play Console shows no target API warnings

## Phase 5 — Release validation (0.5–1 day)
- Install signed release build on Android 13/14/15 devices
- Validate:
  - Import `.smbundle` via share/open intents
  - Playback and orientation-driven fullscreen
  - Storage/temp cleanup and error handling (e.g., low space)
  - No unexpected crashes/ANRs
- Record test notes/screenshots

Acceptance:
- All core flows verified across target Android versions

## Phase 6 — Submission & rollout (0.5–1 day)
- Upload the AAB to an Internal testing track
- Add testers and distribute; verify install/updates
- Resolve any warnings in Pre-launch report
- Promote to Closed/Open testing as desired
- Roll out to Production (consider staged rollout)

Acceptance:
- App visible to intended tracks; Production rollout completes without blocks

## Phase 7 — Post-release monitoring (ongoing)
- Monitor crashes/ANRs and user feedback
- Plan hotfix cadence
- Optional next step: integrate Crashlytics for richer crash diagnostics

---

## Time expectations
- Work time (your side): 1–2 days when assets and policy are ready; 3–5 days if you need to create assets/texts
- Google review time: 3–7 business days for a new app (can vary)
- End-to-end: typically 1–2 weeks; conservative up to 3 weeks

## Notes specific to this project
- The manifest uses intent filters for `.smbundle` sharing/opening; this is generally acceptable. Avoid requesting broad storage permissions.
- The release build currently signs with debug in `build.gradle.kts`; switch to a proper release keystore or rely on Play App Signing with an upload key.
- Play requires AAB uploads; ensure we build with `flutter build appbundle`.
- Security posture in docs is accurate (updated). Ensure the Play listing reflects limitations (no screen recording prevention, device binding to Android ID, offline operation).
