# Project Memory — Pharmacy Profit Control Platform

Durable facts a fresh agent session should know on arrival. Edit in place
when a fact changes.

## Product
Mobile-first business-management app for independent pharmacy owners in
Egypt. Confirmed pilot persona (n=1, real interview): solo/family-operated
pharmacy, shares shifts with her father, smartphone-only, no existing
digital tools, allows customer credit. Non-goal for now: employee-scale
operations (ICP-B), full accounting, customer-facing app, delivery,
insurance, or AI diagnosis — all explicitly out of scope regardless of
future evidence tier.

## Constraints
- **Platform:** Android only. iOS/device-mix is an open question, not a
  decided "no" — see the interview plan in the product spec.
- **Offline/online model:** local-first, best-effort one-way backup sync.
  No real-time sync, no multi-device conflict resolution.
- **Auth model:** none server-side in P0. Local device profile + optional
  PIN. `role` field exists on `UserProfile` but is not enforced.
- **Monetization:** not yet designed into the app — pricing/billing is out
  of scope for every plan in `PLANS/`. When it lands, route payments
  through a compliant Egyptian processor (Paymob/Fawry-style), never
  handle card data directly.
- **Language:** Arabic-primary, RTL. English not yet built.

## Current state
Plan 02 (local identity and access) is complete: onboarding creates
pharmacy + owner atomically and offline; per-profile optional 4-digit PIN
(salted SHA-256 hash in `flutter_secure_storage` under
`pin_hash_<profileId>`, only the key reference in the DB's
`UserProfiles.pin_hash_ref`); profile switcher adds family profiles and
switches the active profile (PIN-gated when set); active profile
persisted (`last_active_profile_id` in secure storage) and attributed via
`activeProfileProvider`; forgot-PIN wipes local identity and re-onboards
(no recovery, stated in-app). Drift tables live in `lib/core/data/tables/`
(shared core layer, not inside the feature). Profile switch navigates
with `go()`, not `pop()` (go_router has no back stack after `go()`).
`test/widget_test.dart` covers RTL boot smoke; `test/features/identity/`
covers the repository and the full identity flows.

Plan 03 (data + sync) is complete: full drift schema (pharmacies with
`remote_uuid`, user_profiles, products with `is_active` soft-delete,
suppliers, customers, append-only ledger_entries; schemaVersion 3);
feature repositories with per-pharmacy isolation; `LedgerEntryType` enum
lives in `lib/core/data/tables/` because core can't import feature code
(the ledger barrel re-exports it — codegen imports it into
`app_database.g.dart`, so any edit to table imports requires re-running
build_runner). One-way ledger backup: device token (256-bit base64url in
secure storage as `device_token_v1`, server stores sha256 hex only,
register-first-wins on uuid), `SyncJob` (batch 200, stamp `synced_at`
only after ack, exponential backoff 5s→5min), `SyncScheduler` (start /
foreground resume / 5s write-debounce / 60s periodic; never throws),
`BackupStatusIndicator` in the dashboard bottom bar. Supabase: migration
`0001_pharmacy_schema.sql` APPLIED to the live project
(vhzvvveikzmuzxzrgbsr, eu-west-1); anon locked to two SECURITY DEFINER
functions; verified live — e2e test (`test_live/rls_isolation_test.dart`,
run with SUPABASE_URL/SUPABASE_ANON_KEY dart-defines from `.env.local`)
and 8/8 server checks (`supabase/tests/rls_isolation_test.sql`) pass.
Credentials live only in gitignored `.env.local`; test_live/ sits
outside test/ so CI can't run it. 46 unit/widget tests green, analyzer
clean, debug APK builds. Sync is ledger-only by decision — products/
suppliers/customers stay local in P0.
Plan 04 (financial ledger domain layer) is complete: four record
use-cases in `lib/features/ledger/domain/usecases/` (`recordDraw`,
`recordSupplierDebt`, `recordCustomerDebt`, `recordRepayment` — each
validates input (positive amount; exactly-one-party for repayments)
before reaching `LedgerRepository.append`, then writes one append-only
entry; they're `async` so validation errors land in the returned
future); three pure calculators in
`lib/features/ledger/domain/calculations/` (`calculateProfit` returning
a `ProfitBreakdown` of sales/cost/draws/net, `calculateOwedToSupplier`,
`calculateOwedByCustomer` — debt minus repayments per party; overpayment
yields a negative credit balance, never clamped, per the plan's edge-
case decision). `calculateProfit` takes an injected `costMinorOf`
resolver because COGS is read from `products.cost_minor` at calculation
time (PLANS/05), not stored in the ledger row — this keeps the
calculators free of drift/feature imports. Use-cases and calculators are
exported through the `ledger.dart` barrel for plan 06's screens. Volume
assumption (PLANS/04 §Performance): in-memory calculation over a
bounded, indexed query result is fine for P0 volumes; revisit by
aggregating at the query level if dashboard queries ever pull unbounded
history.
Plan 05 (product + sales entry) is complete: product catalog —
`ProductFormScreen` (name, cost/sell price, optional expiry date;
required, positive prices parsed by `core/format/money.dart`
`parseEgpToMinor` — Arabic/Western digits, 2 decimals max; form is a
`pushNamed` route with `extra: Product?` for create-vs-edit),
`ProductsScreen` (live `activeProductsProvider` StreamProvider over the
active profile's pharmacy, soft-deactivate with confirm dialog —
products are never hard-deleted), sales screen (case-insensitive
search, cart lines with quantity steppers, running total via
`formatEgp` — `NumberFormat('#,##0.00', 'ar_EG')` pinned because plain
`ar` falls back to Latin digits outside localization delegates — each
line writes one append-only `sale` row through `recordSale` at the
current sell price, attributed to the active profile; per-line
non-atomic appends by decision). Feature barrels now export their
`presentation/` providers (`products.dart`,
`ledger.dart` exports `ledger_providers.dart`) so screens only import
barrels. 95 unit/widget tests green, analyzer clean; runtime pass on
the emulator done (add/edit/validate/deactivate/sale flows). Sales and
products are route-reachable only — dashboard navigation is plan 07's
job. See `FEATURES.md` for per-plan status.

Plan 06 (draws + supplier/customer debt screens) is complete: the three
screens are UI-only on the plan 03/04 domain+data layers (per decision,
the plan file's data-layer sections are stale). Draws screen posts
`recordDraw`; supplier/customer screens show live balances via
presentation StreamProviders that merge the party table with the
type-filtered ledger streams through `combineLatest3` (`core/streams/`),
sorted non-zero first; overpayment renders `رصيد دائن` credit, never
clamped. No delete path in P0 (soft-deactivation deferred, destructive
deletion blocked). `supplierListWithBalancesProvider` /
`customerListWithBalancesProvider` are exported through the feature
barrels; dialogs/strings are in `app_ar.arb`. 112 unit/widget tests
green (17 new: flows 14 + streams 3), analyzer clean; runtime pass on
the emulator done (draw persisted across restart, debt → repayment →
credit for both supplier and customer). Screens are route-reachable
only — dashboard navigation is plan 07's job.

Plan 07 (profit dashboard) is complete: `DashboardScreen` (default route
when a profile is active) with a `SegmentedButton<DashboardRange>`
(today / this week / this month; week starts Saturday — Egyptian
calendar), a profit card (net = sales − cost − draws, computed live via
`calculateProfit` with COGS resolved from `products.cost_minor` per sale
entry — plan 04 semantics), an all-time balances card (total owed to
suppliers / by customers — deliberately NOT range-scoped, per
`DECISIONS.md` 2026-08-03), and a five-tile nav hub to sales, products,
draws, supplier debt, customer debt. Data flows through
`dashboardProvider` — an autoDispose StreamProvider combining
`watchEntries(range)` + `watchEntries(all)` + `watchAll(products)`
(products `watchAll` includes deactivated rows so historical sales still
resolve COGS) via `combineLatest3`. `DashboardRange`/`rangeOf` are pure
and unit-tested. `DashboardData.empty()` renders the onboarding-style
empty state with a CTA to sales. Widget-test lesson (see `DECISIONS.md`
2026-08-03): the onboarding creation flow lands on the dashboard, so
identity flow tests dispose the dashboard's drift-watch providers when
they navigate away — `test/support/helpers.dart` now provides
`unmountAndFlushDriftTimers` (runAsync + pump interleave) for any test
that navigates away from a drift-watching screen. 132 unit/widget tests
green, analyzer clean; runtime pass on the emulator done (real-data
figures verified: today −150.50 vs month −50.50 = 152.00 sales − 52.00
cost − 150.50 draws; range switch + nav hub navigation live; no new
runtime errors — the main.dart:48 "Zone mismatch" assert is pre-existing
MCPToolkit dev-tooling noise). Plan 07 closes P0's "where does my money
go" problem; next: `PLANS/08_TESTING_AND_RELEASE_HARDENING_PLAN.md`.

## Tooling (installed 2026-08-02, AI Engineering OS full setup)
- Global OpenCode config (`~/.config/opencode/`): global `AGENTS.md`
  installed; `opencode.jsonc` now has the 8 CORE_SYSTEM files in
  `instructions` (auto-loads every session), `default_agent: build` +
  plan/build permission overrides, and MCP servers `dart` (dart
  mcp-server) + `context7` enabled, `github` disabled.
  `~/.config/opencode/agent` → AGENTS/ and `~/.config/opencode/skills`
  → SKILLS/ symlinks.
- `flutter-mcp-toolkit` binary 3.1.0 (stable, pinned over the 4.0.0-dev
  prerelease the installer defaults to) at `~/.local/bin` (PATH added to
  `~/.zshrc`); wired into this project's `opencode.json` as the
  `flutter-mcp-toolkit` MCP server (`serve`). Runtime verification of
  critical flows (plan 06) uses it against a debug-mode running app.
- In-app: `mcp_toolkit: ^3.0.0` added; `main.dart` boots through
  `MCPToolkitBinding.instance.bootstrapFlutter` (debug-only VM-service
  extensions, inert in release). Analyzer clean, 112/112 tests pass.
  See `DECISIONS.md` (dependency governance entry) for the package
  checks and the `codegen-init`/`init opencode` upstream gaps.

## Things intentionally NOT done (don't propose these as gaps)
- No backend authentication — deliberate, see `ARCHITECTURE.md` §Identity.
- No employee-role enforcement — the field exists, the behavior doesn't.
  Confirm demand before building (spec §10-11).
- No expiry alerting logic — the optional field exists on `Product` for
  exactly this reason; alerting logic ships once confirmed, not before.
- No real-time/multi-device sync — one-way backup only.
- No e-invoicing/ETA implementation — gated behind `COMPLIANCE.md`
  confirmation, not a normal backlog item.
- No iOS build — Android only this round.
