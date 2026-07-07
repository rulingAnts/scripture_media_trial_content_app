# Scripture Media App — repo guide for Claude / LLMs

Flutter app (`mobile_app/`) that plays scripture audio/video **`.smbundle`** bundles,
plus a bundle-builder (under `desktop-app/scripts`). Bundles are delivered to a field
kiosk by the **village-kiosk "Tugas"** app: downloaded from a public Backblaze B2 bucket
(`kiosk-barnabas`) and opened with `kiosk-app scripture <path>` → `mobile_app <bundle-path>`
(the bundle path is the player's first CLI/dart-entrypoint arg).

> Logged 2026-06-17 during the village-kiosk setup. The **kiosk launch path**
> (Tugas → download → `mobile_app <path>`) is **WORKING and verified**. The items below
> are app/bundler concerns to revisit in a FOCUSED session **after the kiosk is
> deployed** — they are NOT kiosk blockers. Seth's strong prior: the app + bundler code
> are probably **not broken**; most of this is bundle-config, verification, and the
> obfuscation scheme.

## Known issues / things to revisit (after kiosk deployment)

### 1. Play-limit / expiration behaviour — verify it's the bundle, not the app
On the kiosk VM a bundle's video showed the correct thumbnail but wouldn't play.
Diagnosis: the bundle's **play limit / expiration date had been exceeded** (from repeated
testing) → showing the first frame and refusing to play is **working as designed**.
TODO: generate a FRESH bundle with looser/no limits, confirm clean playback, and confirm
this is purely the limit logic (no latent player bug). Belief: app/bundler are fine.

### 2. Imported-file storage — can a filesystem user extract/redistribute the media?
Investigate where imported bundle media lands on disk and in what form. Threat: a user
with filesystem access (Android, or the kiosk) copies the UNENCRYPTED media and
redistributes it, defeating controlled distribution. Determine current storage + close
any plain-file exposure (see #4).

### 3. Play-count / limit RESET on new bundle import (clean slate)
Importing ANY new bundle MUST **reset all existing play counters/limits to a completely
clean slate**, then apply the new bundle's limits. Concretely: a media file that was
played (and counted) under an OLD bundle should get a FRESH count when a NEW bundle is
imported. Verify/implement: new import = full reset of all existing counters first.

### 4. Media must NOT be stored as plain mp3/mp4 — restore "light obfuscation"
Media must NOT sit on disk as plain `.mp3`/`.mp4`, nor as plain files with a proprietary
extension. The app previously had **light obfuscation**: media is playable ONLY inside
the player, but WITHOUT heavy per-play encryption (full encryption on every play is too
much CPU/battery on cheap Android phones — deliberately rejected). Restore/verify this
light-obfuscation so casual extraction is blocked without crippling playback.

## Companion task (from the kiosk plan): hide the in-app "load bundle" file picker
Add a per-bundle flag (baked into the `.smbundle`, carried in its device-verified config)
that **hides the in-app "Import / Load bundle" file-picker** — a back-door filesystem
browser on the locked-down kiosk — while keeping the **argv/`.smbundle` command-line
import** that Tugas relies on. Set the flag in the bundle-builder; read it in `mobile_app`
to hide only the picker entry points. Bundle-scoped (a researcher's own bundles stay
full-featured). See the village-kiosk repo's `docs/DEPLOYMENT-PLAN.md` §6.

## Related
- **village-kiosk** repo (`rulingAnts/village-kiosk`, private): the Tugas app +
  `kiosk-app scripture <path>` launcher (launch side done + verified). Bundles: public B2
  bucket `kiosk-barnabas`.
- Fast on-VM dev loop for the Linux build lives in the user's memory note
  `scripture-app-dev-loop` (Xvfb :99 + flutter run + USR1 hot-reload + screenshots).

---

## ⚠️ GitHub costs — ask before anything billable (firm policy, 2026-07-07)

**Claude: never trigger anything that can incur GitHub charges without Seth's explicit
approval AND a stated cost estimate first.**

- FREE, always: Actions on **public** repos with **standard** GitHub-hosted runners;
  self-hosted runners; GitHub Pages.
- METERED (free monthly quota, then paid): Actions in **private** repos (2,000 min/mo;
  **Windows counts 2×, macOS 10×**); Codespaces; Packages; Git LFS.
- **ALWAYS billable, even on public repos: larger / GPU runners** (anything beyond the
  standard `ubuntu-latest` / `windows-latest` / `macos-latest` tiers).
- Safety valve: with **no payment method on file, GitHub blocks usage at the quota and
  cannot bill** — keep it that way, or set stop-usage budgets.

So WITHOUT Seth's explicit OK (and cost), do **not**: add or change `.github/workflows/**`;
use a non-standard `runs-on:`; add a `schedule:` (cron) trigger; create Codespaces; use
Git LFS; publish private Packages; or change the plan / budgets. The local
`.git/hooks/pre-push` blocks workflow pushes (override `ALLOW_WORKFLOW_PUSH=1`) and
production-branch pushes (`ALLOW_MAIN_PUSH=1`) — set those flags only after Seth approves
that specific push.
