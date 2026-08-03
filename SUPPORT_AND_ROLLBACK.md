# Support, Rollback and Release Signing — Pharmacy Profit Control Platform

Pilot-readiness runbook (PLANS/08 steps 4-6). The pilot is a real pharmacy
owner's real financial records — this file exists so a mid-pilot problem is
handled deliberately, not improvised. Read `DECISIONS.md` for the decisions
referenced here.

## 1. Pilot support (no in-app channel)

The pilot customer has no in-app support, chat, or help desk. Incident path:

1. Contact happens manually (phone/WhatsApp) — keep a contact note for the
   pilot owner outside this repo.
2. Before escalating, collect:
   - What she was doing when it happened (screen, action)
   - Whether the app restarted on its own
   - The device model and Android version (Settings → About)
   - If reproducible: a screen recording or photo of the error text
3. Because crash reporting is deferred (see §4), a crash with no photo is
   invisible — prioritize collecting the above while she still has the phone
   in hand.

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

Crash reporting was deliberately deferred to post-pilot (user decision
2026-08-03, `DECISIONS.md`) — no Crashlytics/Sentry dependency in P0. Until
it ships:

- A pilot crash is only visible if the pilot owner reports it — §1's
  collection habit is the compensating control.
- If the device is in reach: `adb logcat -d` (needs USB debugging enabled)
  or a bug report capture the stack; otherwise the error text on screen is
  all we get.
- Post-pilot: wire a crash-reporting SDK (Firebase Crashlytics or
  equivalent, dependency-governance check first), with the SDK's own
  crash screen for the owner.
