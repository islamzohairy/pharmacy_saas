# 09 — Crash Visibility Plan

## Objective
The pilot's only error signal today is a non-technical owner noticing
something and thinking to mention it. This plan makes a crash *visible
locally* — shown on the dashboard, exportable as a plain-text artifact
support can act on, and cleared only by an explicit report action. Runs
after plan 08.

## Scope
**Included:** local error capture (zone guard + framework + platform
handlers), a local drift table (`schemaVersion` 4), a dashboard error
indicator with clipboard export and an explicit report action, and the
companion fixes from the staff review — hub back-navigation, the stale
`ARCHITECTURE.md` Remote/Authorization paragraph, and `.flutter_mcp/`
hygiene.
**Excluded:** any crash-reporting SDK and any network delivery — the log is
LOCAL-ONLY by decision (rationale at the bottom). Crashlytics-grade
reporting is revisited when pilot count moves past one device.

## Business Context
The pilot is happening now, with one non-technical owner and no in-app
support channel. A silent crash (e.g. one that drops a day's entries)
could damage trust in "the numbers" before the team hears about it at all.
The design target is not analytics — it is "an error is visible to the
owner the moment she opens the app, and the diagnostic artifact is one
long press away as plain text."

## Technical Design
All three capture layers write to one `ErrorLogRepository` backed by the
existing SQLCipher-encrypted drift DB:

1. `runZonedGuarded` around `main()` — catches async/zone escapes.
2. `FlutterError.onError` — framework errors; the previous handler is
   chained (MCPToolkit's debug forwarding preserved), not replaced.
3. `PlatformDispatcher.instance.onError` — engine errors that escape the
   zone; the prior handler is called first and its result returned, so
   default crash semantics are unchanged.

Every write is fire-and-forget with failures swallowed — a logging bug
must never take the app down. Writes before the DB opens (startup race)
are dropped silently rather than buffered.

**Storage:** new `error_log_entries` table (`occurred_at`, `error_type`,
message, truncated `stack_trace`, nullable `reported_at`). Schema v4
migration. LOCAL-ONLY by decision: like products/suppliers/customers, this
never rides the ledger sync surface (which has RPCs for ledger entries
only — no new RPC, no diagnostics on the server).

**UI:** `ErrorLogIndicator` beside `BackupStatusIndicator` on the dashboard
bottom bar. Shows the unreported count; hidden at zero. Tap opens a dialog
listing the entries with two actions: "نسخ التقرير" copies a plain-text
report (timestamp / type / message / truncated stack per entry) to the
clipboard — a Flutter core API, no new dependency, offline, no privacy
surface — and "تم التبليغ" marks them reported. Opening the report dialog
never clears the count; only the explicit report action does.

## File Structure Impact
**New:** `lib/core/data/tables/error_log_table.dart`,
`lib/core/data/error_log_repository.dart`,
`lib/core/data/error_log_providers.dart`,
`lib/core/data/error_log_capture.dart`,
`lib/core/widgets/error_log_indicator.dart`.
**Modified:** `lib/main.dart` (guard + handler install),
`lib/core/data/app_database.dart` (table + v4),
`lib/features/dashboard/presentation/dashboard_screen.dart` (bottom bar),
`lib/core/l10n/arb/app_ar.arb` (+ generated l10n), hub/CTA nav call sites,
back-nav widget tests, new repository/indicator tests, `ARCHITECTURE.md`,
`.gitignore`, `SUPPORT_AND_ROLLBACK.md`.

## Implementation Steps
1. Drift table + migration (`schemaVersion` 4), regenerate codegen.
2. Capture layer ([installErrorLogCapture]) and guarded `main`.
3. Repository + providers + indicator + dashboard wiring + arb strings,
   regenerate l10n.
4. Tests: repository (append / count / mark-reported / truncation /
   newest-first ordering) and indicator widget (hidden at zero / count +
   dialog / export to clipboard / report action clears).
5. Reviewer companion fixes: hub and CTA `goNamed` → `pushNamed` with
   back-nav widget tests; `ARCHITECTURE.md` Remote section rewrite;
   `git rm --cached .flutter_mcp` + ignore.
6. Verify: `flutter analyze` clean, full suite green, release-mode
   runtime pass on the emulator (back navigation + dashboard bottom bar).
7. Docs: `DECISIONS.md`, `FEATURES.md`, `PROJECT_MEMORY.md`,
   `SUPPORT_AND_ROLLBACK.md`.

## Dependencies
Plan 08's schema + verification path; plan 07's dashboard layout (the
bottom bar the indicator joins).

## Testing Strategy
Unit tests for the repository; widget tests for the indicator interaction
(clipboard mocked via `SystemChannels.platform`, which asserts the report
text actually reached the handler); full-suite regression; release-mode
runtime pass.

## Edge Cases
- Error before the DB is ready → dropped (startup race, documented).
- Report-write failure → swallowed inside the capture handler.
- Huge stack/message → truncated at write inside the column limits.
- Provider in error state (e.g. tests without a DB) → indicator renders
  nothing (`valueOrNull`, never rethrows).
- Same-instant inserts → ordering tiebreak by descending `id`.
- RTL/back: preserve `goNamed` for replacement flows (onboarding →
  dashboard, profile picker/entry); `pushNamed` for hub/CTA.
- The two hub tiles tests and the sales CTA tests must still pass.

## Security Considerations
Purely local data with no new permission, network, or server surface —
clipboard export only contains strings already on device. The chained
handlers preserve existing crash semantics; the RPC surface is untouched.

## Performance Considerations
One lightweight COUNT stream subscribed only while the dashboard is
mounted; writes are single-row fire-and-forget. No rebuild or query
concerns for pilot volumes.

## Rationale for "local-only, no SDK"
Crashlytics (or equivalent) would make reporting automatic rather than
visible, but it needs a new Firebase project, a new dependency (with the
governance check), a network path to deliver — which cuts against this
app's local-first posture — and its marginal value at exactly one pilot
device is low. The local export closes the actual gap (invisible →
visible-to-the-owner + material artifact) without carrying that cost.
Revisit the SDK decision the same way every other deferred item is
revisited here: when pilot count moves past one device, not before.