# Architecture — Pharmacy Profit Control Platform

Full rationale for every decision below: `ENGINEERING/ENGINEERING_STRATEGY.md`.
This file states the *current* decision only — read that one for *why*, and
for alternatives considered.

## Layer structure
Matches the global default in `FLUTTER_STANDARDS.md` exactly —
feature-first, Clean Architecture layering (`presentation` / `domain` /
`data`) per feature under `lib/features/<feature>/`.

## State management
Riverpod, hand-written providers. No codegen. Matches global default — no
deviation.

## Data layer
- **Local:** `drift` (not raw `sqflite`) — compile-time-checked queries,
  matters given money correctness. Encrypted at rest (`sqlcipher`).
  Local DB is always the source of truth for reads.
- **Remote:** Supabase managed Postgres — storage only; Supabase Auth is
  **not used in P0** (deferred; identity is the local device profile, see
  below). The anon role has no direct table access: all
  select/insert/update/delete privileges are revoked, RLS is enabled on
  every table, and there are no direct-table policies. The only server
  surface anon can reach is two SECURITY DEFINER functions,
  `register_device` and `push_ledger_entries`. Backup auth is a per-install
  256-bit device token in secure storage (the server stores only its
  SHA-256 hash; the tenant is derived from the token hash, never from the
  payload). The server-side ledger is append-only — the push function only
  inserts, idempotent on the composite `(pharmacy_id, id)` key. Full model
  and live verification: `SECURITY.md` §Backup write path.
- **Sync model:** local-first writes, one-way best-effort background
  backup (local → remote) on foreground + connectivity. No real-time sync,
  no multi-device conflict resolution yet — deliberately deferred, not an
  oversight (see `PROJECT_MEMORY.md`).
- **Repository pattern** at the domain/data boundary — domain code depends
  on repository interfaces only, never on `drift`/Supabase concretely. This
  is what keeps the local/remote split invisible above the data layer.

## Core entities
`Pharmacy` (tenant root; compliance-prep fields `tax_registration_number`
and `legal_business_name` since schema v5) → `UserProfile` (role:
owner/family/employee, role captured but not yet enforced) → `Product`
(cost/sell price, optional expiry) → `LedgerEntry` (**append-only**,
typed: sale / expense / supplier_debt / customer_debt / debt_repayment,
integer minor-unit amounts; `expense` rows carry an `ExpenseCategory`:
ownerDraw/rent/utilities/supplies/other) → `Supplier`, `Customer`. Full
schema: `PLANS/03_DATA_AND_SYNC_PLAN.md`, schema changes:
`PLANS/10_EXPENSES_ACTIVITY_AND_SETTINGS_PLAN.md`.

**The one rule that matters most in this schema:** `LedgerEntry` rows are
never updated or deleted, by anyone, for any reason. A correction is a new
offsetting entry. All balances (profit, amount owed) are computed live by
aggregation over the ledger — never stored as a mutated running total.

## Navigation
`go_router`. P0 routes: onboarding/profile, product entry, sales entry,
expenses, activity, supplier debt, customer debt, dashboard (default
post-onboarding route), settings.

## Identity / access (P0)
Local device profile only — no backend login. See `SECURITY.md` and
`PLANS/02_IDENTITY_AND_ACCESS_PLAN.md`. Do not build server-side auth
unless `DECISIONS.md` records that this has changed.

## Localization
Arabic-primary, RTL-first from the first screen. All strings through
`intl`. English is a plausible future toggle, not P0.

## Platform
Android only for P0. iOS is future scope, gated on confirming device/OS
mix in the target segment (currently unconfirmed — see `PROJECT_MEMORY.md`).

## Key architectural decisions currently in force
See `DECISIONS.md` for the full log with reasoning. Summary: Supabase over
Firebase/custom backend; local-only identity over backend auth for P0;
append-only ledger over mutable balances; Riverpod over Bloc despite this
being a money-movement app; `drift` over raw `sqflite`; Android-first
platform strategy.

## Known deviations from CORE_SYSTEM defaults
None. This project follows `FLUTTER_STANDARDS.md`'s stated defaults
throughout (Riverpod hand-written, `drift`-equivalent local DB, `go_router`,
repository pattern). The Bloc-vs-Riverpod question `FLUTTER_STANDARDS.md`
itself raises for money-movement apps was evaluated explicitly and
resolved in favor of the default — see `DECISIONS.md`.
