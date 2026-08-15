# Features — Pharmacy Profit Control Platform

## Shipped
- 01_PROJECT_FOUNDATION_PLAN — project foundation (Android-only
  implementation, feature-first folder tree, go_router skeleton with 7 P0
  route stubs, Arabic-primary RTL l10n via intl/gen-l10n, drift
  connection wired with SQLCipher encryption, Supabase client
  configuration wiring (CI workflow added in plan 08 — plan 01's
  "CI analyze+test on push" claim was a documentation mismatch; no
  workflow existed before plan 08)). No feature logic
  shipped — every screen is a stub.
- 02_IDENTITY_AND_ACCESS_PLAN — local device identity: onboarding
  (pharmacy + owner created atomically, offline, RTL), optional 4-digit
  PIN per profile (salted hash in secure storage), profile switcher with
  family-profile addition, active-profile persistence + attribution, PIN
  gate on profile switch, forgot-PIN wipe with in-app limitation notice.
  Roles (`owner`/`family`/`employee`) are captured and displayed but not
  enforced — no server auth, no login screen, per plan scope.
- 03_DATA_AND_SYNC_PLAN — full drift schema for all P0 entities
  (`pharmacies` + `remote_uuid`, `user_profiles`, `products` with
  soft-delete flag, `suppliers`, `customers`, append-only
  `ledger_entries`), feature repositories with per-pharmacy isolation,
  one-way ledger backup to Supabase: device-token registration
  (SHA-256 hash server-side, register-first-wins on uuid), batched
  idempotent pushes (composite `(pharmacy_id, id)` PK), background
  scheduler (start/foreground-resume/write-debounce/60s periodic,
  exponential backoff), in-app backup-status indicator (RTL),
  server-side RLS with anon locked to two SECURITY DEFINER functions.
  Verified against the live project (migration applied; e2e + 8 server
  checks passed). Unsynced-only ledger backup — products/suppliers/
  customers stay local by plan scope.
  **CORRECTION (2026-08-05, Plan 11-H):** the gate runs (incl. the
  plan-10 deploy gate) proved RLS isolation but never the app's real
  wire payload — their push payloads omit party ids, so every real app
  push 409'd on the four never-populated reference FKs (fixed by remote
  migration `0003_ledger_party_reference_fks.sql`; evidence in
  DECISIONS.md 2026-08-05). The gate now pushes a realistic app payload,
  asserts the post-0003 FK count, and is self-cleaning (no residue per
  run).
- 04_FINANCIAL_LEDGER_PLAN — financial domain layer: four record
  use-cases (`recordDraw`, `recordSupplierDebt`, `recordCustomerDebt`,
  `recordRepayment` — validated, attributed, append-only) and three pure
  calculators (`calculateProfit` with sales/cost/draws breakdown via an
  injected cost resolver, `calculateOwedToSupplier`,
  `calculateOwedByCustomer` — live-derived, overpayment → negative
  credit, never clamped). Unit-tested against an in-memory fake
  repository; no UI ships in this plan.
- 05_PRODUCT_AND_SALES_PLAN — product catalog + sales entry: product
  create/edit form (name, cost/sell price in EGP with Arabic-Indic
  entry, optional expiry date, required positive prices), live products
  list with soft-deactivate (confirm dialog, history preserved), sales
  screen (case-insensitive product search, add-to-cart lines with
  quantity steppers, running total, per-line append-only `sale` ledger
  writes via `recordSale` at the current sell price, attributed to the
  active profile), EGP money helper (`formatEgp`/`parseEgpToMinor` in
  `core/format/money.dart`, integer minor units end-to-end). Sales/
  products are route-reachable only — dashboard navigation is plan 07.
  Runtime-verified on the emulator (add/edit/validate/deactivate/sale).
- 06_DEBT_AND_DRAW_TRACKING_PLAN — draws, supplier debt, customer debt:
  draws screen (amount + optional note, `recordDraw` through the ledger),
  supplier screen (live `supplierListWithBalancesProvider` merging
  suppliers + debt/repayment ledger streams, create-supplier dialog,
  record-debt/repayment dialogs, `رصيد دائن` credit display on
  overpayment — never clamped), customer screen as the mirror image,
  empty/error states, Arabic-Indic EGP amounts. UI-only by decision
  (repos/use-cases shipped in 03/04); no delete path in P0 (soft-
  deactivation deferred, destructive deletion blocked). Presentation
  merge via `combineLatest3` (`core/streams/`), no rxdart.
  Runtime-verified on the emulator (draw persisted across restart,
  debt → repayment → credit, supplier + customer).
  112 unit/widget tests green, analyzer clean.
- 07_PROFIT_DASHBOARD_PLAN — profit dashboard (default landing when a
  profile is active): range selector (today / this week / this month,
  week starts Saturday), live profit card (net = sales − cost − draws
  with per-sale-entry COGS resolution, deactivated products still
  resolve historical cost via `watchAll`), all-time supplier/customer
  debt totals (deliberately not range-scoped, per DECISIONS.md), empty
  state with CTA, five-tile nav hub to sales/products/draws/supplier
  debt/customer debt, backup indicator + profile entry retained.
  Widget-test fix: shared `unmountAndFlushDriftTimers` helper for tests
  that navigate away from drift-watching screens (drift close timers
  under fake_async — see DECISIONS.md lesson). 132 unit/widget tests
  green, analyzer clean. Runtime-verified on the emulator (real-data
  figures, range switch recomputes, nav hub navigation).
- 08_TESTING_AND_RELEASE_HARDENING_PLAN — pilot release gate:
  `.github/workflows/ci.yaml` (analyze + full suite + `flutter build apk
  --release` on push/PR; classified plan-required per the AGENTS.md
  discovery rule — plan 01 never shipped CI despite its docs claim),
  local gate verified (132/132, release APK builds), RLS live isolation
  test re-run green, release-mode e2e on the emulator (full P0 flow,
  exact dashboard figures), conditional release signing in
  `android/app/build.gradle.kts` (gitignored `android/key.properties`
  when present, debug fallback otherwise — no secrets in repo/CI),
  `SUPPORT_AND_ROLLBACK.md` (pilot support §1, version-tagged APK
  rollback §2, signing runbook §3, crash-gap manual path §4), crash
  reporting deferred to post-pilot (user decision, DECISIONS.md),
  P0-shipped entries recorded.
- 09_CRASH_VISIBILITY_PLAN — local crash visibility (staff-review
  follow-up): local error capture (zone guard + chained
  FlutterError/PlatformDispatcher handlers) into a drift
  `error_log_entries` table (schema v4), LOCAL-ONLY by decision (sync
  surface untouched); `ErrorLogIndicator` on the dashboard bottom bar
  (unreported count, hidden at zero; tap → export plain-text report to
  clipboard — no new dependency, no privacy surface — and explicit
  report action; dashboard view never clears the count). Also closed the
  back-navigation gap (hub/CTA now `pushNamed` — system/AppBar back
  returns to the dashboard) and fixed `ARCHITECTURE.md`'s stale Remote/
  Authorization paragraph. 142 tests green; release-mode runtime pass.
- 10_EXPENSES_ACTIVITY_AND_SETTINGS_PLAN — expenses, activity history,
  compliance-prep settings: `cashDraw` → `expense` with a `category`
  column (`ExpenseCategory`: ownerDraw/rent/utilities/supplies/other,
  local schema v5 + migration backfilling stored draws), `draws` feature
  replaced by `expenses` (category picker with Owner Draw default, past-
  expenses list; profit net of every expense — not just owner draws),
  activity feed (last 100 entries + recorder names, new 6th hub tile),
  settings screen (dashboard AppBar icon; pharmacy tax registration
  number + legal business name, inert compliance-prep capture).
  Wire-format phase shipped separately on main as PR #1 (camelCase →
  snake_case `LedgerEntryType.wireName`). **Deploy gate:** cleared 2026-08-04 —
  `supabase/migrations/0002_expense_category.sql` applied to the live project,
  `rls_isolation_test.sql` re-run green. 159 tests green, analyzer clean;
   backfill verified via raw-seeded fixtures (no real pilot DB copy).
- 11_PILOT_HARDENING_AND_OBSERVABILITY_PLAN — pilot hardening and
  observability: guarded DB open (`DatabaseOpenException` +
  `openWithGuard`, `openAppDatabase` failure → non-destructive fatal
  screen with copy-report + manual retry — never deletes/recreates the
  file, never auto-retries), derived backup staleness (`oldestUnsyncedAt`
  on `LedgerRepository`, pure `evaluateBackupStaleness` vs 48h threshold
  — no schema change, no `sync_metadata` table; clock-set-backward masks
  staleness as pending, accepted), stale warning chip + explanation
  dialog on the backup indicator (stale overrides error display),
  sync-scheduler catch-all hardening (non-`StateError` identity-layer
  throws now surface via the error log instead of escaping the run
  loop), `RELEASES.md` (version-tag conventions + per-release checklist)
  and `SUPPORT_AND_ROLLBACK.md` §5 pilot-ops protocol. 179 tests green,
  analyzer clean, release APK builds. Release-mode runtime pass on the
  emulator: onboarding → dashboard, product + sale entry, live dashboard
  aggregation, error-state indicator non-destructive (live 401 from a
  stale local anon key — config issue, not app code), cold-restart data
  persistence. Stale-state runtime repro blocked by emulator environment
  (no adb root, `-qemu -rtc` unsupported) — covered by unit/widget
  tests instead. The runtime backup failure seen here was the remote FK
  bug (409 23503 — the anon key was valid all along; the "401 stale key"
  reading was RLS denial on direct table access, misread). Fixed
  2026-08-05 via migration 0003 + deploy gate; on-device acceptance:
  error chip → synced ("آخر نسخة: 5/8/2026 11:10"), entries stamped
  remotely. Plan 11-H also fixed the indicator's no-op-pass bug: an
  already-registered pass with nothing to push left the chip at
  "syncing" forever on relaunch — the scheduler now derives the real
  last-sync time from stamped entries (`LedgerRepository.lastSyncedAt`).
  Plan 11-H Phase 1 (write-triggered sync acceptance) found and fixed the
  scheduler self-disposal bug: `syncSchedulerProvider` `ref.watch`ed the
  status provider it writes, so the first pass's own status update
  invalidated and disposed the scheduler (dead timers, chip stuck at
  syncing). Fixed via `ref.read` (sync_providers.dart) + regression test
  (RED on old wiring, GREEN on fix); DECISIONS.md 2026-08-05 has the
  root-cause entry and the never-watch-what-you-write rule. Phase 1 gate
  (sale→debounce, idle→periodic, relaunch→resume pushes on the emulator)
  PASSED on the fixed build (2026-08-05: 3 trigger paths, no scheduler
  dispose, chip synced after each push). The release re-verify found a
  second bug: the main manifest lacked the INTERNET permission (stock
  template — debug/profile only), so release builds could never sync
  (DNS denied, masked as "Failed host lookup"). Fixed in the main
  manifest; release push verified end-to-end (first ever successful
  release push 14:53, chip synced 14:54); SnackBar dismiss re-verified
  on the clean release build (visible +2s, gone +8s). The earlier
  "release APK" 11:10 acceptance record is corrected (definitive): that
  acceptance was verified on a DEBUG build; release builds could not sync
  until the INTERNET manifest fix (first successful release-mode sync
  14:53) — see DECISIONS.md 2026-08-05.

- 12_INVENTORY_FOUNDATION_PLAN — inventory foundation: append-only
  `stock_movements` drift table (schemaVersion 7; `initial` /
  `stock_in` / `stock_out` / `adjustment` types, signed-delta quantities,
  profile attribution, nullable note; local-only — nothing leaves the
  device), `inventory` feature (StockRepository, live on-hand via grouped
  SUM over the movement ledger), optional initial-stock capture on
  product creation (one `initial` movement, Arabic-Indic digit
  normalization, hidden on edit), live on-hand + negative-stock error
  color on the product list. Migration rehearsed twice: v6→v7 fixture
  (2026-08-13, first checkpoint) and on-device against real pilot data
  (emulator-5556 acceptance install, release build — data intact,
  first successful push observed on the new build). Deploy gate re-run
  green on the resumed backend (RLS isolation test, self-cleaning).
  224 tests green, analyzer clean. See DECISIONS.md 2026-08-13.
  (Count corrected at Plan 13 acceptance: the "224" was a momentary
  pre-`50a0492` measurement — Plan 12 closed at 225/225 at `50a0492`.)

- 13_INVENTORY_DEDUCTION_AND_ADJUSTMENT_PLAN — sale auto-deduction and
  manual stock adjustment (schemaVersion 8, local-only — zero changes
  under `supabase/` or `core/data/sync/`): `pharmacies.auto_deduct_stock`
  drift column (default ON, additive migration, rehearsed twice — v7→v8
  fixture 2026-08-13 and on-device 2026-08-13-13:00 on emulator-5556 with
  Plan 12's real data intact), Settings toggle (fresh-read inside sale
  confirm, D8), sequential sale-first auto-deduct hook posting one
  `stock_out` per sale line for tracked products only (D6/D9), product-row
  action sheet ("المخزون: إضافة / تصحيح" vs "تعديل بيانات المنتج",
  chevron cue), two-mode adjustment sheet (add posts `stock_in`; correct
  posts signed-delta `adjustment`; zero-delta rejected; live Arabic
  previews), and the activity feed merged across ledger + manual movements
  (D10: auto `stock_out`/`initial` absent; 100-combined cap by recency).
  Runtime-passed end-to-end on the release APK (tracked sale deducts
  ١٠٠→٩٩; untracked sale no-op; toggle off stops deduction; add ٩٩→١٠٤;
  correct →١٢٠ with "الفرق: ١٦ · الجديد: ١٢٠" previews; feed renders both
  movement types attributed + signed quantities). 257 tests green (225 baseline at
  `50a0492` + 32 new: +1 migration, +15 deduct, +8 adjustment, +8 feed),
  analyzer clean. See DECISIONS.md 2026-08-13 (D6–D10, device-leg pass,
  fake-async lesson, acceptance reconciliation + sync confirmation).

- 14_INVENTORY_SIGNALS_AND_INSIGHTS_PLAN — signals & insights (schemaVersion
  9, local-only — zero changes under `supabase/` or `core/data/sync/`):
  nullable `products.low_stock_threshold` column (additive migration,
  rehearsed twice — v8→v9 fixture 2026-08-13 and on-device 2026-08-13-15:36
  on emulator-5556 with real pilot data intact, all thresholds NULL),
  pure `stockSignal()` derivation (D14: tracked-only, out-of-stock = ≤ 0,
  low = threshold set ∧ 0 < on-hand ≤ threshold), threshold field on the
  product form create+edit (D15: config, never a movement), title-row
  signal badges on the product list (نفد المخزون errorContainer /
  مخزون منخفض tertiaryContainer, untracked → none), and two dashboard
  additions alongside the range selector — the products hub tile's live
  attention count (D14 signals, drops when an item resolves healthy; the
  other five tiles pass null) and the أعلى مصروف expense insight line
  (D16: top category + share, follows today/week/month, hides on an empty
  range). Device-runtime-passed on the release APK: sold A to zero →
  نفد المخزون, threshold 150 > 120 on Aspirin → مخزون منخفض, insight
  hidden at ٠٫٠٠ then shown إيجار ١٠٬٠٠٠ (١٠٠٪), attention count ٢ == the
  two list badges. 290 tests green (257 baseline + 33: +1 migration, +8
  signal, +6 threshold, +6 badges, +12 dashboard), analyzer clean,
  release APK builds (74.8MB with `.env.local` defines). See DECISIONS.md
  2026-08-13 (D14–D16, Phase 0 gate, rehearsal record + Step 8 device leg).

## In progress
None — all P0 plans (01–09), plans 10–14 are complete.
Next work is gated on pilot feedback and the P1 confirmations in the
roadmap below.

## Roadmap — P0 (build order; each plan states its own dependencies)
| # | Plan | Confirmed problem it answers |
|---|---|---|
| 01 | `PLANS/01_PROJECT_FOUNDATION_PLAN.md` | scaffolding — no direct product answer |
| 02 | `PLANS/02_IDENTITY_AND_ACCESS_PLAN.md` | flexible access model |
| 03 | `PLANS/03_DATA_AND_SYNC_PLAN.md` | schema + backup (data-loss risk) |
| 04 | `PLANS/04_FINANCIAL_LEDGER_PLAN.md` | draws, supplier debt, customer debt, profit calc |
| 05 | `PLANS/05_PRODUCT_AND_SALES_PLAN.md` | product entry, sales entry |
| 06 | `PLANS/06_DEBT_AND_DRAW_TRACKING_PLAN.md` | draw/debt screens |
| 07 | `PLANS/07_PROFIT_DASHBOARD_PLAN.md` | "where does my money go" |
| 08 | `PLANS/08_TESTING_AND_RELEASE_HARDENING_PLAN.md` | pilot readiness gate |
| 09 | `PLANS/09_CRASH_VISIBILITY_PLAN.md` | crash visibility for the pilot (post-review) |
| 10 | `PLANS/10_EXPENSES_ACTIVITY_AND_SETTINGS_PLAN.md` | where money goes beyond draws; activity visibility; ETA prep |
| 11 | `PLANS/11_PILOT_HARDENING_AND_OBSERVABILITY_PLAN.md` | pilot hardening: DB-open safety, backup staleness visibility |
| 12 | `PLANS/12_INVENTORY_FOUNDATION_PLAN.md` | inventory: on-hand visibility, initial stock capture |
| 13 | `PLANS/13_INVENTORY_DEDUCTION_AND_ADJUSTMENT_PLAN.md` | sale auto-deduction, manual stock adjustment, movements in activity feed |
| 14 | `PLANS/14_INVENTORY_SIGNALS_AND_INSIGHTS_PLAN.md` | low/out-of-stock signals, expense insight (final §4.2 increment) |

## Roadmap — P1 (not started, not yet planned in detail)
- Expiry alerting logic (data field already ships in P0 — see
  `PROJECT_MEMORY.md`) — gated on Sprint 0 interview confirmation.
- Employee-restriction enforcement (role field already ships in P0) —
  gated on ICP-B or trust/control confirmation.
- Detailed batch tracking, purchase-order workflow, reports beyond
  dashboard, shift/handoff summary.
- E-invoicing/e-receipt (ETA) compliance — gated behind `COMPLIANCE.md`,
  not a normal backlog item; do not plan implementation before that file
  shows `confirmed-by-counsel`.

## Roadmap — P2+ (not started)
Customer profiles/refill reminders, WhatsApp order intake, multi-branch
management, forecasting/AI recommendations.

## Explicitly out of scope
Full accounting suite, customer-facing app, delivery, insurance, AI
diagnosis — regardless of future evidence tier (per product spec §11).

## Release history
None yet.
