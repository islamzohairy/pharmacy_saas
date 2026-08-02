# 03 — Data Layer and Sync Plan

## Objective
Define the full local (`drift`) schema shared by every P0 feature, and the
background backup-sync path to Supabase that closes
`ENGINEERING_REVIEW.md` F5 (data-loss risk on a single device).

## Scope
**Included:** complete local schema for all P0 entities, repository
interfaces per entity, the local-first write path, the background
push-to-Supabase job, remote Postgres schema + RLS policies mirroring the
local shape.
**Excluded:** real-time sync, multi-device conflict resolution beyond
last-write-wins, pull-side sync (restoring from backend onto a new device)
— defer to when multi-device is confirmed.

## Business Context
Every other P0 feature plan depends on this schema existing first. Getting
the ledger shape right here is what makes F3 (money-representation risk)
and F5 (data-loss risk) non-issues for every feature built on top.

## Technical Design
**Local schema (`drift`):**
- `pharmacies(id, name, currency, created_at)`
- `user_profiles(id, pharmacy_id, role, display_name, pin_hash_ref)`
- `products(id, pharmacy_id, name, cost_minor, sell_minor, expiry_date
  NULLABLE)` — expiry present and optional per spec §10's hedge.
- `suppliers(id, pharmacy_id, name)`, `customers(id, pharmacy_id, name)`
- `ledger_entries(id, pharmacy_id, type, amount_minor, product_id
  NULLABLE, supplier_id NULLABLE, customer_id NULLABLE, profile_id,
  occurred_at, note NULLABLE, synced_at NULLABLE)` — `type` ∈ `sale`,
  `cash_draw`, `supplier_debt`, `customer_debt`, `debt_repayment`.
  **Append-only: no update/delete path exists on this table anywhere in the
  codebase.** A correction is a new offsetting `ledger_entries` row.

All money columns are `INTEGER` minor units (piastres), never `REAL`/float.

**Remote schema:** same shape in Postgres, plus RLS policy scoping every
table to `pharmacy_id = auth.jwt() -> 'pharmacy_id'` (or equivalent) once
real auth exists — for P0, remote writes go through a scoped
service-role/anon-key path tied to the device's pharmacy, since there's no
end-user auth yet (§6, plan 02).

**Sync:** a background `WorkManager`/`Isolate`-based job pushes any
`ledger_entries` row with `synced_at IS NULL` to Supabase on app foreground
+ connectivity, then stamps `synced_at`. One-way (local → remote) only for
P0.

## SOLID Application
Repository interfaces (`LedgerRepository`, `ProductRepository`, etc.) live
in `domain/`; `drift`-backed and Supabase-backed implementations live in
`data/`. Every other feature's domain code depends on the interface only —
this is what makes the local/remote split invisible above the data layer,
directly answering `AI_ENGINEERING_OS_REVIEW.md` Gap 1.

## File Structure Impact
**New:** `lib/core/data/` (drift database definition, all table classes),
`lib/core/data/sync/` (background sync job), repository interfaces per
feature's `domain/`, repository implementations per feature's `data/`,
Supabase migration files.
**Modified:** `01_PROJECT_FOUNDATION_PLAN.md`'s empty `drift`/Supabase
wiring gets real tables.

## Implementation Steps
1. Define all `drift` tables above; generate and review the migration.
2. Write repository interfaces for each entity.
3. Implement `drift`-backed repositories (local, always source of truth
   for reads).
4. Set up matching Supabase Postgres schema + migration, with RLS
   policies scoped to `pharmacy_id`.
5. Implement the background sync job: query unsynced `ledger_entries`,
   push, stamp `synced_at`; retry with backoff on failure; never blocks
   any UI write.
6. Add a simple in-app "last backed up" indicator so the owner has
   visibility into backup status — directly addresses the trust concern
   behind F5.

## Dependencies
Requires `01_PROJECT_FOUNDATION_PLAN.md`. Feeds every subsequent plan.

## Testing Strategy
Unit tests: repository CRUD (append-only enforcement — verify no
update/delete method exists on `LedgerRepository`), sync-job logic against
a mocked Supabase client (queues correctly, retries on failure, doesn't
double-push already-synced rows). Integration test: full write → local
persist → simulated sync → verify remote row matches, since this is
explicitly a critical/data-loss-risk flow per `DEFINITION_OF_DONE.md`.

## Edge Cases
- App killed mid-sync — job must be resumable, not lose or duplicate
  entries (idempotent push keyed by local `id`).
- No connectivity for extended periods — local writes must keep working
  indefinitely; sync just accumulates a backlog.
- Two ledger entries with the same `occurred_at` — fine, `id` is the
  uniqueness key, not timestamp.

## Security Considerations
Local DB encrypted at rest (`sqlcipher` via `drift`) per
`ENGINEERING_STRATEGY.md` §6. Supabase RLS policies must be tested to
confirm one pharmacy's data is genuinely unreachable from another
tenant's credentials — this is the single most important test in this
plan given the multi-tenant SaaS shape.

## Performance Considerations
Index `ledger_entries` on `(pharmacy_id, occurred_at)` and `(pharmacy_id,
type)` per `ENGINEERING_STRATEGY.md` §7 — dashboard queries (plan 07)
depend on these.

## Acceptance Criteria
- Full schema matches this plan exactly; every money column is integer
  minor units.
- No update/delete code path exists on `ledger_entries` anywhere.
- A ledger entry written offline appears in Supabase within one sync cycle
  after connectivity returns.
- RLS policy test proves cross-tenant data isolation.

## Builder AI Instructions
**Do:** treat the append-only constraint on `ledger_entries` as
non-negotiable — enforce it at the repository interface level (no
`update`/`delete` method exposed), not just by convention.
**Do not:** implement real-time/live sync, multi-device merge logic, or
pull-from-remote restore in this plan — explicitly deferred.
**Common mistakes:** using `double`/`REAL` for any money column; adding an
`update` method to `LedgerRepository` "for convenience" — don't, corrections
are new offsetting rows.
**Definition of done:** matches `DEFINITION_OF_DONE.md`, with the
`VERIFIED:` line explicitly stating the RLS cross-tenant isolation test was
run, not just assumed from the policy definition.
