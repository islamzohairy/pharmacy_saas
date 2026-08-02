# Features — Pharmacy Profit Control Platform

## Shipped
- 01_PROJECT_FOUNDATION_PLAN — project foundation (Android-only
  implementation, feature-first folder tree, go_router skeleton with 7 P0
  route stubs, Arabic-primary RTL l10n via intl/gen-l10n, drift
  connection wired with SQLCipher encryption, Supabase client
  configuration wiring, CI analyze+test on push). No feature logic
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

## In progress
None — next up: `PLANS/06_DEBT_AND_DRAW_TRACKING_PLAN.md`.

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

## Roadmap — P1 (not started, not yet planned in detail)
- Expiry alerting logic (data field already ships in P0 — see
  `PROJECT_MEMORY.md`) — gated on Sprint 0 interview confirmation.
- Employee-restriction enforcement (role field already ships in P0) —
  gated on ICP-B or trust/control confirmation.
- Detailed batch tracking, purchase-order workflow, expense tracking,
  reports beyond dashboard, shift/handoff summary.
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
