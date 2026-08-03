# Review Package — Pharmacy Profit Control Platform

Index file for a staff-engineer review of everything accomplished from
project start through the P0 pilot gate (2026-08-03). Read the sections
below in order; each file is required unless marked `optional`.

The full `git` history on `main` (commits 0df3297..6ce4b52) is part of
the review — run `git log --oneline` before reading code.

## 1. Product intent
- `product/pharmacy_saas_product_specification-2.md` — confirmed-problem
  spec every plan traces back to.

## 2. Project docs — decisions and architecture
- `AGENTS.md` — working rules incl. the discovery/scope-control directive
  that shaped how plans were executed and deviations were logged.
- `PLANS/01_PROJECT_FOUNDATION_PLAN.md` .. `PLANS/08_TESTING_AND_RELEASE_HARDENING_PLAN.md`
  — the eight-plan contract the code is reviewed against; read in order
  (each states its own dependencies).
- `ARCHITECTURE.md` — structure and key decisions in force.
- `DECISIONS.md` — append-only decision/tradeoff log (the "why we didn't
  do X" record).
- `PROJECT_MEMORY.md` — durable facts: stack, toolchain, live Supabase
  identity.
- `SECURITY.md` — threat model.
- `COMPLIANCE.md` — e-invoicing/ETA gating; anything e-invoice related is
  not a normal backlog item until counsel confirmation is marked here.
- `FEATURES.md` — shipped status, recorded known issues, roadmap.
- `SUPPORT_AND_ROLLBACK.md` — pilot support, rollback, signing runbook.
- `ENGINEERING/ENGINEERING_STRATEGY.md` — source "why" when
  `ARCHITECTURE.md` doesn't answer a question deeply enough.

## 3. Backend contract
- `supabase/migrations/0001_pharmacy_schema.sql` — tenant isolation, RLS,
  SECURITY DEFINER functions; the authoritative security boundary.
- `supabase/tests/rls_isolation_test.sql` — server-side RLS verification.

## 4. Configuration
- `pubspec.yaml` — dependencies and versions.
- `analysis_options.yaml` — lint gate.
- `l10n.yaml` + `lib/core/l10n/arb/app_ar.arb` — RTL-first string sources.
- `.github/workflows/ci.yaml` — CI gate (analyze + suite + release APK).
- `android/app/build.gradle.kts` — release signing (conditional,
  keystore-free).
- `android/app/src/main/AndroidManifest.xml` — permissions (`optional`).

## 5. Source — the code review unit (whole `lib/`)
The app is compact, so the entire `lib/` tree is the honest minimum
complete unit; read it in this order:
1. `lib/main.dart`, `lib/app.dart` — bootstrap, initial-route decision
2. `lib/core/router/app_router.dart` — P0 route table
3. `lib/core/data/` — drift schema (`tables/`), `app_database.dart`,
   `sync/` (backup scheduler), `secure_store.dart`
4. `lib/core/format/money.dart` — money invariant (integer minor units,
   Arabic-Indic formatting)
5. `lib/core/streams/` — stream-combining helpers
6. `lib/features/<feature>/` ×8 — Clean-Arch layers, read via each
   feature barrel; call outs: `ledger/domain/` (calculations + record
   use-cases = business correctness), `dashboard/` (headline feature),
   `identity/` (local-device identity + PIN)

## 6. Tests
- `test/` — whole suite (repo layer; current gate is 132 tests).
- `test_live/rls_isolation_test.dart` — live-Supabase isolation test;
   `optional`, needs creds from the gitignored `.env.local`, excluded
   from CI by design.

## Explicitly NOT included
- `.env.local` — contains live secrets; never share.
- `android/key.properties` — does not exist yet; keystore generation is
  a pilot-time action (runbook in `SUPPORT_AND_ROLLBACK.md` §3).
- `pubspec.lock`, `build/`, `.dart_tool/`, `.git/` — derivable or
  generated.
- iOS/macOS/windows/linux/web scaffolding — non-target platforms
  (Android-only P0).
- `ENGINEERING/` review-process artifacts (AI_ENGINEERING_OS_REVIEW.md,
  ENGINEERING_REVIEW.md) — internal to the AI engineering setup, not the
  product.

## Review gate expectations
- Everything here ran `flutter analyze` clean with zero warnings at merge
  time and the full test suite green (132/132 at plan 08 close).
- Release-mode runtime verification was performed on a real emulator
  (full Arabic/RTL P0 flow); CI reproduces the same gate on GitHub
  Actions (`push`/`PR`).
- Recorded known issue (back navigation) lives in `FEATURES.md` "Known
  issues (deferred)" with fix direction in `DECISIONS.md` (2026-08-03
  entry) — candidate for the next plan, not a defect in the shipped
  gate.
