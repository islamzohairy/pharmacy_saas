# 10 — Expenses, Activity History, and Compliance-Prep Settings Plan

Supersedes the standalone `Draws` feature and closes out
`PRODUCT_DIRECTION_FINAL.md` items (b), (c), (d). Item (a) needed no
change — `PLANS/02_IDENTITY_AND_ACCESS_PLAN.md` is already validated as
built correctly.

## Objective
Three things, done together because they touch overlapping code and were
confirmed together: (1) fix a pre-existing wire-format bug discovered
during this review, unrelated to product scope but touching the same
files; (2) restructure cash draws into a general Expenses area with
categories; (3) add a read-only activity-history view and optional
business/tax fields in settings.

## Scope
**Included:** Phase 0 bug fix (below); `LedgerEntryType.cashDraw` →
`expense` + `category` field; Expenses screen replacing the Draws screen
and route; activity-history screen (read-only); optional
`taxRegistrationNumber`/`legalBusinessName` fields on `Pharmacy` +
settings screen to edit them.
**Excluded:** any e-invoice/e-receipt implementation (stays behind
`COMPLIANCE.md`'s `confirmed-by-counsel` gate, untouched by this plan);
employee-role enforcement; expiry alerting; remote sync of pharmacy
settings (local-only, matching the existing scope boundary for
products/suppliers/customers).

## Business Context
`PRODUCT_DIRECTION_FINAL.md` closes out the four decisions left open
after the P0 pilot review. Three matched what's built; one (Expenses)
didn't and needed a real scope call, made here. Phase 0 is unrelated to
that document — it's a correctness bug found while reading the exact code
this plan already has to touch.

## Technical Design

### Phase 0 — Wire-format bug fix (do this first, independently reviewable)
`LedgerEntryType.wireName` (`core/data/tables/ledger_entry_type.dart`)
currently returns `name` — Dart's camelCase identifier (`cashDraw`,
`supplierDebt`, `customerDebt`, `debtRepayment`). The remote whitelist in
`supabase/migrations/0001_pharmacy_schema.sql` (both the `ledger_entries`
CHECK constraint and `push_ledger_entries`'s validation) expects
snake_case (`cash_draw`, `supplier_debt`, `customer_debt`,
`debt_repayment`). Only `sale` happens to match either way. Replace the
one-line getter with an explicit exhaustive `switch` so the compiler
forces every future type to declare its wire form — the same pattern
this plan uses for the new `category` field, so this bug class can't
recur silently:
```dart
String get wireName => switch (this) {
  LedgerEntryType.sale => 'sale',
  LedgerEntryType.expense => 'expense',
  LedgerEntryType.supplierDebt => 'supplier_debt',
  LedgerEntryType.customerDebt => 'customer_debt',
  LedgerEntryType.debtRepayment => 'debt_repayment',
};
```
No local data migration is needed for this fix — local storage was never
wrong, only the outgoing serialization was. `sync_job.dart`'s existing
design (`synced_at` stamped only after a successful push) means the fix
self-heals the existing backlog on the next successful `runOnce` pass —
no manual backfill job. **Do** confirm on the real pilot device, after
this ships, that the unsynced count actually drains to zero — don't just
trust a fresh-database test pass.

### Phase 1 — Schema (local + remote)
**Local (`schemaVersion` 4 → 5):**
- Rename `LedgerEntryType.cashDraw` → `LedgerEntryType.expense`.
- New enum `ExpenseCategory { ownerDraw, rent, utilities, supplies,
  other }` with its own explicit `wireName` switch (same pattern as
  Phase 0 — don't reintroduce the bug on the new field).
- `LedgerEntries` table: new nullable `TextColumn category =>
  textEnum<ExpenseCategory>().nullable()()` — type-conditional exactly
  like the existing `productId`/`supplierId`/`customerId` columns (only
  set when `type == expense`), same established pattern in this file.
- `Pharmacies` table: new nullable `taxRegistrationNumber`,
  `legalBusinessName` text columns.
- Migration step (`onUpgrade`, `if (from < 5)`): `addColumn` for all
  three new columns, then one `customStatement`:
  `UPDATE ledger_entries SET type = 'expense', category = 'ownerDraw'
  WHERE type = 'cashDraw'`. This is a one-time schema-correction
  migration, not an app-level ledger edit — the append-only rule governs
  `LedgerRepository`'s write surface during normal operation, which this
  migration doesn't go through.

**Remote — new file `supabase/migrations/0002_expense_category.sql`,
never edit `0001_pharmacy_schema.sql` in place (it's already applied to
the live project; editing it changes nothing there and desyncs the repo
from reality):**
- `alter table public.ledger_entries add column category text check
  (category in ('owner_draw','rent','utilities','supplies','other'));`
- Update `push_ledger_entries`'s type whitelist to accept `'expense'`
  (keep `'cash_draw'` in the whitelist too — already-synced historical
  rows on the remote side keep that value forever since there's no
  restore/backfill path yet; this is a deliberate, documented gap, not an
  oversight — revisit only if a restore-from-remote feature is ever
  built) and thread `category` through the same `nullif(...)` optional-
  field pattern already used for `product_id`/`supplier_id`/etc.
- `RemoteLedgerEntry`/`_toRemote` (`sync_job.dart`): add nullable
  `category` field, serialized via `ExpenseCategory.wireName`.

### Phase 2 — Expenses feature (replaces Draws)
- `lib/features/ledger/domain/usecases/record_draw.dart` →
  `record_expense.dart`: same shape as today's `recordDraw`, plus a
  required `ExpenseCategory category` parameter, writing
  `LedgerEntryType.expense` with that category.
- `lib/features/draws/` → renamed `lib/features/expenses/` (barrel,
  presentation). Screen: category picker (Owner Draw first/default — it's
  still the highest-frequency expense type and the original "log a draw
  fast" property must not regress) + amount + optional note, and a list
  of past expenses with category shown.
- `app_router.dart`: remove `AppRoutes.draws` / `/draws`; add
  `AppRoutes.expenses` / `/expenses`. Hub tile updated to point at it
  (label/icon: "Expenses" / `Icons.receipt_long_outlined` or similar —
  keep `Icons.payments_outlined` if preferred, product decision either
  way).
- `dashboard_providers.dart`: `DashboardData.drawsMinor` →
  `expensesMinor`, summing **all** `expense`-type entries regardless of
  category (profit must be net of every expense, not just owner draws —
  `PRODUCT_DIRECTION_FINAL.md` §2 is explicit about this). `netMinor`
  calculation unchanged in shape, just the renamed field.
  `calculateProfit` (plan 04) similarly renames its `drawsMinor` output
  to `expensesMinor`, summing by type regardless of category.
- `l10n/arb/app_ar.arb`: replace `drawsTitle` with an expenses-area set
  (title, category labels, "Owner Draw" as the default option) — follow
  the existing key + `@key` description convention exactly.

### Phase 3 — Activity history (additive, no schema change)
- `LedgerRepository.watchEntries` (interface + `DriftLedgerRepository`):
  add an optional `int? limit` parameter (default `null` = unbounded, so
  every existing caller — dashboard's all-time debt aggregation — is
  unaffected). Apply via `..limit(limit)` only when non-null.
- New `lib/features/activity/` (presentation + a small domain helper that
  maps a `LedgerEntry` + resolved profile display name into a display
  row). Calls `watchEntries(pharmacyId: ..., limit: 100)` (already
  ordered `occurred_at DESC, id DESC` — no new query logic needed) and
  `IdentityRepository.getProfiles()` once to resolve `profileId` →
  `displayName` for rendering "who."
- New route `/activity`, new 6th hub tile alongside Sales/Products/
  Expenses/Supplier Debt/Customer Debt.

### Phase 4 — Compliance-prep settings fields (additive, local-only)
- `Pharmacy` domain entity: add nullable `taxRegistrationNumber`,
  `legalBusinessName`.
- `IdentityRepository`: new `Future<Pharmacy> updatePharmacySettings({...})`
  — the first update-after-onboarding path for this entity; everything
  else about `Pharmacy` has been create-once until now.
- New settings screen (`lib/features/identity/presentation/settings/`)
  reachable from the dashboard AppBar (a new icon alongside the existing
  profile-switcher icon — not a 7th hub tile; this is low-frequency, and
  the hub should stay focused on daily-use actions). Both fields
  optional, no validation beyond basic length limits — this is inert data
  capture, explicitly not a compliance feature.
- `COMPLIANCE.md`: add one line noting these fields now exist for future
  use, with an explicit note that this does **not** change the
  e-invoicing item's `unconfirmed` status or the gate around it.

## SOLID Application
Same shape as every prior plan: `record_expense` is a pure use-case
depending on `LedgerRepository`'s interface only; the activity screen
reads through `LedgerRepository`/`IdentityRepository` interfaces, no new
concrete dependency; `ExpenseCategory`'s `wireName` lives next to the
type it describes, not scattered into the sync layer.

## File Structure Impact
**New:** `lib/features/expenses/` (replacing `draws/`),
`lib/features/activity/`, `lib/features/identity/presentation/settings/`,
`supabase/migrations/0002_expense_category.sql`.
**Modified:** `ledger_entry_type.dart`, `ledger_entries_table.dart`,
`pharmacies_table.dart`, `app_database.dart` (schema v5), `app_router.dart`,
`dashboard_providers.dart`, `ledger_repository.dart` +
`ledger_repository_impl.dart` (limit param), `sync_job.dart` +
`remote_backup_client.dart` (category field, wireName fix),
`identity_repository.dart` + impl (settings update method), `pharmacy.dart`,
`app_ar.arb`, `COMPLIANCE.md`.
**Removed:** `lib/features/draws/` (folded into `expenses/`).

## Implementation Steps
1. Phase 0: fix `wireName`, add the regression test described below, ship
   independently reviewable even if the rest takes longer.
2. Local schema: add `ExpenseCategory`, rename the type, add the three
   new columns, write the v5 migration with the backfill statement, run
   it against a copy of real pilot data if available (not just a fresh
   test DB) to confirm the backfill behaves as expected.
3. Remote schema: write `0002_expense_category.sql`, apply it to the live
   Supabase project, update `push_ledger_entries` and the CHECK
   constraint, re-run `supabase/tests/rls_isolation_test.sql`.
4. Rename `record_draw.dart` → `record_expense.dart`; update every call
   site (compiler will surface them via the enum rename).
5. Build the Expenses screen from the Draws screen; update routing,
   hub tile, l10n.
6. Update `dashboard_providers.dart`/`calculateProfit` field rename;
   update every test referencing `drawsMinor`.
7. Add `limit` to `watchEntries`; build the activity screen; add route +
   hub tile.
8. Add `Pharmacy` fields, `updatePharmacySettings`, settings screen,
   AppBar entry point.
9. Update `COMPLIANCE.md`, `FEATURES.md`, `ARCHITECTURE.md` (mention the
   `category` field and settings additions where relevant), `DECISIONS.md`
   (log the Expenses schema call and the Phase 0 bug fix as separate
   entries — they have different causes and shouldn't be merged into one
   log entry).

## Dependencies
Requires all of P0 (`PLANS/01`-`09`) — builds directly on the ledger
(plan 04), identity (plan 02), and dashboard (plan 07) work.

## Testing Strategy
- **Phase 0:** a test asserting every `LedgerEntryType.values` `.wireName`
  against the literal remote whitelist strings, with a comment pointing
  at `0001_pharmacy_schema.sql`/`0002_expense_category.sql` — this is the
  test that should have existed already; make sure it fails against the
  old `=> name` implementation before confirming the fix.
- Unit tests: migration backfill (existing `cashDraw` rows become
  `expense`/`ownerDraw` post-migration, on a populated test DB, not just
  an empty one); `recordExpense` for each category;
  `calculateProfit`'s renamed `expensesMinor` summing across mixed
  categories.
- Widget tests: Expenses screen (category picker, Owner Draw default),
  activity screen (correct who/what/when rendering, correct ordering,
  `limit` respected), settings screen (optional fields, no validation
  blocking submission when empty).
- Re-run the full existing suite — the type rename touches enough call
  sites that a green full-suite run (not just new tests) is the real
  gate here.

## Edge Cases
- Migrating a pharmacy with zero existing `cashDraw` rows — backfill
  statement must be a safe no-op, not an error.
- An expense recorded with category `other` and no note — must not be
  blocked; "other" is a legitimate, final category choice, not a
  placeholder forcing a note.
- Activity history on a fresh pharmacy with zero entries — clear empty
  state, not a blank list.
- A ledger entry whose `profileId` no longer resolves to a profile
  (shouldn't happen — profiles aren't deleted — but resolve defensively
  to a "—" placeholder rather than crashing the list).
- Remote whitelist now accepting both `cash_draw` (historical) and
  `expense` (current) — confirm the RPC test suite covers both values,
  not just the new one.

## Security Considerations
No change to the security model — `category` and the two pharmacy fields
follow the same encryption-at-rest and (for `category`) same tenant-scoped
RPC path as everything else already flowing through those tables. The
Phase 0 fix doesn't touch authorization at all, only serialization
correctness.

## Performance Considerations
`watchEntries`'s new `limit` parameter is additive and only applied when
passed — the dashboard's unbounded all-time debt-aggregation call is
unaffected. The activity screen's `limit: 100` keeps it bounded regardless
of how much history accumulates.

## Acceptance Criteria
- `wireName` test passes; a manually-triggered sync push succeeds for a
  batch containing every entry type, verified against the live project.
- Existing `cashDraw` rows read back as `expense`/`ownerDraw` after
  migration; no data loss, no duplicate rows.
- `/draws` route no longer exists; `/expenses` replaces it with category
  selection and Owner Draw as the fast default.
- Dashboard's expense figure matches the sum of all expense-type entries
  regardless of category, not just Owner Draw.
- Activity screen shows correct who/what/when, newest first, capped at
  the configured limit.
- Settings screen saves and persists the two optional fields;
  `COMPLIANCE.md`'s e-invoicing item is untouched and still `unconfirmed`.
- Full test suite green; analyzer clean; release build succeeds.

## Builder AI Instructions
**Do:** treat Phase 0 as independently shippable and prioritize it if
there's any schedule pressure — it's a live-data-risk fix, not a nice-to-
have.
**Do:** write `0002_...sql` as a new file; never edit `0001_...sql`.
**Do not:** touch anything behind `COMPLIANCE.md`'s gate — the tax/legal-
name fields are data capture only, not the start of e-invoice work.
**Do not:** let the Expenses screen's category picker regress the
one-tap speed of logging an Owner Draw — that fast-logging property was
the original reason draws got their own screen; preserve it inside the
new screen.
**Common mistakes:** forgetting that `sale` matching in both cases makes
the wire-format bug easy to miss in ad hoc testing — test every non-sale
type explicitly, not just the one that happened to work. Editing
`0001_pharmacy_schema.sql` instead of adding `0002` — it has no effect on
the already-deployed database and silently desyncs the repo from reality.
**Definition of done:** matches `DEFINITION_OF_DONE.md`; this plan touches
a live pilot's real financial data through a migration for the first time
in this project — verify the migration against a copy of real pilot data
if at all possible, not only a fresh empty database.
