# Releases — NoNota (نونوتا)

Version-tag → artifact → rollback mapping for the closed pilot (PLANS/11
§4.4 / §8). The pilot owner's real financial records are at stake — every
APK handed out must be taggable, testable, and replaceable. Read
`SUPPORT_AND_ROLLBACK.md` before doing anything operational.

## Conventions

- **Tag = `v<versionName>-<yyyymmdd>`**, e.g. `v1.0.0-20260805`, applied as a
  git tag on the exact commit the APK was built from.
- **Artifact = the built APK, kept forever** outside the repo under
  `releases/` (or a private location), named
  `app-release-<tag>.apk` — a git tag alone is NOT enough; rebuilds are not
  guaranteed byte-identical, and rollback needs the exact file.
- Version bump: `pubspec.yaml` (`version:` — becomes Android versionName)
  and the Android `versionCode` (also derived from pubspec; bump per
  release). One release = one commit that bumps the version.
- **Signing:** a release APK must be signed with the real keystore
  (`SUPPORT_AND_ROLLBACK.md` §3) before it reaches the pilot device.
  Debug-signed and keystore-signed APKs cannot replace each other in place.
- Migration rule: every release that ships a local schema change must have
  rehearsed the migration against a copy of real pilot data first — the
  standing rule in `AGENTS.md`. No release ships an unrehearsed migration.

## Pilot release log

| Tag | versionCode | Built from (commit) | What shipped | APK | Rollback target |
|---|---|---|---|---|---|
| — | — | — | (no releases yet — plan 11 sets up the discipline before the first pilot install) | — | — |
| v0.1.0-pilot | 1 | 02570d7 | First pilot install — keystore-signed (CN=Islam Zohairy, Skypiecode; SHA-256 222d5e2a…78), label NoNota, defines baked in, smoke-passed on emulator (shop+PilotPharm product+sale 15.00 EGP, backup chip 13:38→13:41). Tag on the exact build commit; pubspec stays 1.0.0+1 (custom pilot label, see DECISIONS.md) | app-release-v0.1.0-pilot.apk (archived ../releases/, 74.8MB, sha256 9b7ed9b8…96) | none (first install) |

## Rollback procedure (quick reference)

1. Rollback = install the previous tagged APK **over** the current one —
   non-destructive (same signing key, local data untouched).
2. If the current release has a pending local migration, the rollback
   **must** be checked against `RELEASES.md`/`DECISIONS.md` for a schema
   mismatch (downgrade across a schema bump is not automatic).
3. A rollback is a support event: collect the in-app error report first
   (`SUPPORT_AND_ROLLBACK.md` §1), then decide with the recorded evidence.
4. Full detail: `SUPPORT_AND_ROLLBACK.md` §2.

## Release checklist (per release)

- [ ] `flutter analyze` clean; full suite green (all tests, not just new)
- [ ] Release APK builds with env defines baked in
      (`flutter build apk --release --dart-define-from-file=.env.local`)
- [ ] Release-mode runtime pass on the emulator: fresh install, full P0
      flow, exact dashboard figures
- [ ] Local migration rehearsed against a copy of real data (if any)
- [ ] Signed with the real keystore; `apksigner verify` fingerprints recorded
- [ ] Version bumped; tag `v<version>-<date>` pushed; APK archived by tag
- [ ] This file updated (tag → artifact → rollback target)
