-- 0003_ledger_party_reference_fks.sql
-- Plan 11-H: drop the four reference foreign keys on ledger_entries that
-- P0 never populates on the remote mirror.
--
-- Background / evidence:
--   * The remote mirror's products / suppliers / customers / user_profiles
--     tables are never written by P0 (0001 declares schema parity with the
--     local drift schema; the backup path is ledger-only — DECISIONS.md
--     2026-08-02). Verified live: all four tables hold 0 rows on the pilot
--     project (2026-08-05).
--   * The app always sends party ids on its real payloads (product_id from
--     the sales flow, profile_id from the active profile). Every push
--     therefore fails server-side with HTTP 409 / SQLSTATE 23503:
--       `Key (profile_id)=(1) is not present in table "user_profiles"`
--       `Key (product_id)=(1) is not present in table "products"`
--     reproduced live from the exact app payload shape (2026-08-05,
--     register_device -> push_ledger_entries).
--   * The gate tests (supabase/tests/rls_isolation_test.sql, test_live)
--     passed because their payloads omit party ids — they proved RLS
--     isolation, never the app's actual wire shape. The gate is upgraded
--     in 0003's companion change to assert the post-state and to push a
--     realistic payload (see rls_isolation_test.sql).
--
-- Why this is safe:
--   * The columns (product_id, supplier_id, customer_id, profile_id) stay.
--     Only the FK constraints go; the push whitelist, RLS, and the anon
--     surface are untouched. No new grants, no policy changes.
--   * The referenced tables remain empty-by-construction in P0, so no
--     orphaned referential integrity is lost.
--   * Migration of the historical remote rows (none exist with party ids)
--     is a no-op.
--
-- If P1+ starts syncing parties: re-add the constraints in a NEW migration
-- with `NOT VALID`, then `ALTER TABLE ... VALIDATE CONSTRAINT` after a
-- backfill — never as a blocking VALIDATE on first add.
--
-- Applied live 2026-08-05 (deploy gate: migration + gate re-run green).

alter table public.ledger_entries
  drop constraint if exists ledger_entries_profile_id_fkey;
alter table public.ledger_entries
  drop constraint if exists ledger_entries_product_id_fkey;
alter table public.ledger_entries
  drop constraint if exists ledger_entries_supplier_id_fkey;
alter table public.ledger_entries
  drop constraint if exists ledger_entries_customer_id_fkey;
