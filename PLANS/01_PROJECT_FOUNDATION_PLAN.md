# 01 — Project Foundation Plan

## Objective
Stand up the Flutter project skeleton, folder structure, tooling, and
localization foundation everything else in this package builds on. Nothing
user-facing ships here — this is the scaffold that makes every later plan a
same-shaped addition instead of a one-off.

## Scope
**Included:** repo init, `flutter create`, feature-first folder structure,
lint/analyzer config, `drift` + Supabase client wiring (connections only, no
schema yet — that's `03_DATA_AND_SYNC_PLAN.md`), `go_router` skeleton with
placeholder screens for the P0 flow, `intl`/RTL foundation, CI skeleton
(analyze + test on push).
**Excluded:** any real screen logic, the database schema itself, auth, any
business logic.

## Business Context
Every hour spent later re-deciding folder layout, lint rules, or how
localization is wired is an hour not spent on the four confirmed problems
(spec §1). This plan exists so that decision only gets made once.

## Technical Design
Feature-first + Clean Architecture layering per
`CORE_SYSTEM/FLUTTER_STANDARDS.md` — `lib/core/`, `lib/features/<feature>/
{presentation,domain,data}`. `go_router` configured with route stubs for
onboarding, product entry, sales entry, draws, supplier debt, customer
debt, and dashboard — each pointing at a placeholder `Scaffold` for now.
`intl` initialized with `ar` as the default/primary locale;
`Directionality` verified RTL end-to-end with the placeholder screens
before any real UI is built on top, so RTL bugs are caught here, not
discovered eight screens later.

## SOLID Application
Single Responsibility is enforced structurally: the folder layout itself
prevents a screen file from also containing repository logic, since
`presentation/` has no legal path to a data source. No other SOLID
principle has meaningful surface area at the scaffolding stage.

## File Structure Impact
**New:** `lib/core/` (constants, theme, `l10n/`), `lib/app.dart`,
`lib/main.dart`, `lib/features/<feature>/{presentation,domain,data}/` for
each of the seven P0 features (empty except a route stub),
`analysis_options.yaml`, `.github/workflows/ci.yaml` (or equivalent).
**Modified:** none (fresh project).

## Implementation Steps
1. `flutter create` with correct org identifier and Android-only initial
   platform target.
2. Add `analysis_options.yaml` extending `very_good_analysis` or
   `flutter_lints` + the explicit additions in `GLOBAL_RULES.md`.
3. Create the feature-first folder tree for all seven P0 features, empty.
4. Add `go_router` and wire route stubs for each feature's entry screen.
5. Add `intl`, set `ar` as default locale, verify `Directionality.rtl`
   renders correctly across the placeholder screens.
6. Add `drift` and Supabase client dependencies and connection
   configuration (no schema/tables yet).
7. Wire CI: `flutter analyze` + `flutter test` on every push.
8. Commit with `chore: project foundation`.

## Dependencies
None — this is the first plan.

## Testing Strategy
No business logic exists yet. Verify: `flutter analyze` clean, app builds
and launches to the placeholder home route, RTL layout visibly correct on
a device/emulator set to Arabic.

## Edge Cases
N/A at this stage — flag if `go_router`'s RTL/back-navigation behavior
needs any explicit configuration (verify, don't assume default is correct).

## Security Considerations
Confirm `.gitignore` excludes signing keys and any Supabase service keys
before the first commit — cheap to get right now, expensive to discover a
key was committed later.

## Performance Considerations
None applicable yet.

## Acceptance Criteria
- Project builds and runs on Android.
- Folder structure matches `ENGINEERING_STRATEGY.md` §5 exactly.
- All seven P0 route stubs are reachable and render RTL correctly with
  Arabic strings.
- CI runs analyze + test on push and passes on an empty test suite.

## Builder AI Instructions
**Do:** follow the folder structure exactly as specified — this is the
contract every later plan assumes. Verify RTL rendering visually, not just
by setting the locale flag.
**Do not:** add any screen logic, schema, or auth here — this plan is
scaffolding only. Do not add packages "for later" (see
`GLOBAL_RULES.md` dependency governance).
**Common mistakes:** wiring `intl` but leaving hardcoded English strings in
placeholder screens "since they're just stubs" — replace them now so no
LTR-assumption habit forms in later plans.
**Definition of done:** matches `DEFINITION_OF_DONE.md` for a foundation
task — analyzer clean, builds and launches, no tests required beyond a
smoke test since there's no logic yet.
