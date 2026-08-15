# Support, Rollback and Release Signing — NoNota (نونوتا)

Pilot-readiness runbook (PLANS/08 steps 4-6). The pilot is a real pharmacy
owner's real financial records — this file exists so a mid-pilot problem is
handled deliberately, not improvised. Read `DECISIONS.md` for the decisions
referenced here.

## 1. Pilot support (no in-app channel)

The pilot customer has no in-app support, chat, or help desk. Incident path:

1. Contact happens manually (phone/WhatsApp) — keep a contact note for the
   pilot owner outside this repo.
2. Ask her for the in-app error report FIRST (plan 09): on the dashboard,
   tap the red error line ("أخطاء غير مُبلَّغ عنها (N)") below the top
   bar → "نسخ التقرير" → paste the clipboard text into the message
   (WhatsApp). This is a timestamped plain-text artifact of what crashed
   — no reconstruction from memory needed. If she then taps "تم التبليغ",
   the indicator clears (the report is already in your hands).
3. If no report is available, collect from memory/screen: what she was
   doing (screen, action), whether the app restarted on its own, the
   device model and Android version (Settings → About), and a photo of
   any error text.
4. A crash she never sees (app closes instantly) still shows the
   indicator on next successful open — the count is never auto-cleared by
   opening the dashboard, so ask her to check the dashboard's error line
   even after a restart.

## 2. Rollback plan

- Every APK handed to the pilot is version-tagged: save a dated copy of the
  exact APK file (e.g. `releases/app-release-1.0.0-20260803.apk`) outside the
  repo, alongside the release notes.
- **Rollback = install the previous tagged APK over the current one.**
  - Local data lives in the app's private storage — a reinstall of the same
    signing key does NOT touch it. Rollback is non-destructive by design.
  - ⚠ The one destructive exception: the debug-signed fallback build vs. a
    properly signed release build cannot be installed over each other
    (signature mismatch → Android refuses the update; the only path is
    uninstall + install, which WIPES local data). See §3 — sign before
    distributing to the pilot device, never ship a debug-signed build to her.
- The Supabase one-way ledger backup is a **restore aid**, not a rollback
  mechanism: it protects against a lost/broken phone. It does not restore
  products/suppliers/customers (local-only by plan 03 decision) and there is
  no restore path from backup into a live device in P0.
- If a release-mode bug is found mid-pilot:
  1. Do not panic-ask her to clear data — clear data is data loss.
  2. Install the previous tagged APK (non-destructive, see above).
  3. Fix the bug, run the plan-08 gate (CI + regression), produce a new
     tagged APK, and only then update her.

## 3. Release signing runbook (run locally, secrets never in the repo)

The keystore and `key.properties` are **never** committed (`.gitignore`:
`*.jks`, `*.keystore`, `key.properties`, `.env*`; `android/.gitignore`:
`key.properties`, `**/*.keystore`). CI builds release-mode APKs with the
debug-signing fallback and has no access to signing material.

1. Generate the keystore (one time, keep it safe — losing it means the app
   can never be updated in place again):
   ```
   mkdir -p ~/keys
   keytool -genkey -v -keystore ~/keys/pharmacy_saas-release.jks \
     -keyalg RSA -keysize 2048 -validity 10950 -alias pharmacy_saas
   ```
   Store the passwords in a password manager. Back up the keystore file off
   the machine.
2. Create `android/key.properties` (absolute path, gitignored):
   ```
   storeFile=/Users/<you>/keys/pharmacy_saas-release.jks
   storePassword=<store password>
   keyAlias=pharmacy_saas
   keyPassword=<key password>
   ```
3. Build and verify:
   ```
   flutter build apk --release
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```
   (apksigner is in Android SDK build-tools; the printed SHA-256 fingerprints
   identify the keystore — keep a copy for audit.)
4. With `key.properties` present, the release buildType signs with this
   keystore (`android/app/build.gradle.kts`); without it, it falls back to
   debug signing so CI and local dev never depend on secrets.
5. ⚠ Signature rule for the pilot device: the debug-signed fallback and the
   real keystore cannot replace each other in place. Decide signing FIRST,
   then distribute — a debug-signed APK on her device locks her out of all
   future signed updates without a data-wiping uninstall.

## 4. Crash reporting gap (deferred decision, post-pilot)

Crashlytics/Sentry were deliberately deferred to post-pilot (user decision
2026-08-03, `DECISIONS.md`) — but plan 09 ships the LOCAL half of crash
visibility now:

- Every unhandled error is written to the on-device error log
  (`error_log_entries`, encrypted with the rest of the local DB) and
  surfaced by the dashboard indicator — a crash is visible to her next
  open, and exportable as plain text (§1 step 2). This is the P0
  compensating control; it does not require network, USB, or the team's
  presence.
- What the local log does NOT cover: errors during the first seconds
  before the DB opens (dropped by design), and anything that prevents the
  app from rendering the dashboard at all (e.g. a startup crash) — for
  those, `adb logcat -d` (USB debugging enabled) or a bug report still
  applies if the device is reachable.
- Post-pilot: evaluate a crash-reporting SDK (Firebase Crashlytics or
  equivalent, dependency-governance check first) — automatic delivery
  replaces manual copy-paste; revisit when pilot count moves past one
  device.

## 5. Pilot operations protocol (PLANS/11)

Standing protocol for the two failure classes a pilot install can actually
hit — plus the migration-rehearsal rule. Priority order: business data
correctness → pilot stability → UX → sync reliability.

### 5.1 Database open failure (the fatal screen)

If the app shows "تعذر فتح البيانات" (cannot open data) instead of the
dashboard:

- **What happened:** the local encrypted database failed to open — corrupt
  file, lost encryption key, or a failed migration. The file is NEVER
  deleted or recreated by the app, so **her data is intact on the device**.
  This is the one screen that deliberately does NOT write to the error log
  (the log lives inside the DB).
- **First response — do NOT tell her to clear data or reinstall.** Those
  are data-loss actions.
- Ask her to tap "نسخ التقرير" (copy report) and send the clipboard text.
  The report is minimal by design: timestamp + error text + stack — no
  ledger content, no token material.
- Tap "إعادة المحاولة" (retry) once or twice with her (no automatic loops
  exist — a manual tap is the only retry). If it persists:
  1. Collect the report (above) — this is the primary artifact.
  2. `adb logcat -d` if the device is reachable (USB debugging).
  3. Use §2 rollback: install the previous tagged APK — rollback is
     non-destructive and does NOT fix a corrupt local file by itself, but
     it isolates whether the failure is app-version or device-storage
     related (e.g. failing migration introduced by the new version).
  4. If the file itself is corrupt (report says "malformed"/"not a
     database"), the recovery decision is made by the operator with the
     evidence in hand — never remotely instruct a wipe unprompted.

### 5.2 Backup staleness (the old-backup warning)

If the dashboard shows "آخر نسخة احتياطية قديمة — تحقق من الاتصال" (last
backup is old — check connectivity):

- **What it means:** ledger records have not reached the backup server for
  more than 48 hours. Her data is safe on the device; only the off-device
  copy is at risk.
- Causes, in order of likelihood: phone offline / connectivity issue,
  battery-optimization killing the app's background passes, backend
  problem.
- Operator actions: confirm the Supabase project is up (health check on the
  project dashboard / logs), then ask her to open the app and keep it in
  the foreground a few minutes — each foreground resume and every 60s tick
  retries with backoff. The warning clears itself once a sync succeeds.
- The stale signal is derived (unsynced-entry age vs. device clock) — a
  device clock set backward masks it. If she reports the warning is wrong,
  check the device clock setting before anything else.

### 5.3 Migration rehearsal (standing rule)

- **Every release that ships a local schema change (drift `schemaVersion`
  bump) must rehearse the migration against a copy of real pilot data
  BEFORE the release, and the rehearsal result recorded in `DECISIONS.md`**
  (standing rule, `AGENTS.md`).
- Plan 10's v4→v5 backfill was verified on raw-seeded fixtures only — the
  FIRST real-data migration rehearsal happens before the first pilot
  install and every release after that.
- Rehearsal method: pull a copy of the pilot device's DB file (encrypted —
  use the app's key; or rehearse on a restored-backup dataset), apply the
  new migration path, and verify row counts / typed values match the
  migration's expectation. Record: source of the data copy, before/after
  row counts, and any corrections needed.

### 5.4 Handoff expectations for the pilot

- She will not be told to manage files, clear data, or reinstall — any
  such instruction must come from the operator after §5.1/§5.2 triage.
- All in-app copy is Arabic/RTL; support conversations happen over
  WhatsApp/phone per §1.


## 6. Release-build configuration checklist (pilot gate, 2026-08-15)

Every APK that reaches the pilot device must clear ALL of these — any
failure is a release blocker, not a "fix in the field" item:

- [ ] **(1) INTERNET permission in the MAIN manifest**
      (`android/app/src/main/AndroidManifest.xml`) — the stock template
      ships it only in debug/profile; without it in main, release sync
      silently never runs (Plan 11 lesson, 2026-08-05).
- [ ] **(2) Env defines baked in** — built with
      `flutter build apk --release --dart-define-from-file=.env.local`
      and both `SUPABASE_URL` + `SUPABASE_ANON_KEY` present in
      `.env.local`. A build without them compiles fine but sync silently
      never runs (Plan 13 lesson, 2026-08-13). CI enforces this by
      reconstructing `.env.local` from repo secrets and hard-failing.
- [ ] **(3) Signed with the pilot keystore, not the debug fallback** —
      `apksigner verify --print-certs` shows the real upload cert, not
      "CN=Android Debug" (keystore ceremony: §3 above; no keystore exists
      yet — owner task).
- [ ] **(4) Built via ci.yaml** — the workflow runs analyze + full suite +
      release APK with the env-define hard-fail on every push/PR, so a
      silently unconfigured build cannot pass the gate.
- [ ] **(5) Post-build smoke on a fresh install** — create shop + product +
      record a sale → the backup chip advances to "آخر نسخة: <time>".
- [ ] **(6) Version tag cut + RELEASES.md entry recorded** — tag
      `v<version>-<yyyymmdd>` on the exact build commit; APK archived by
      tag (`RELEASES.md` conventions).
