-- Cross-tenant isolation test for the P0 backup path.
-- The single most important test in plan 03 (plan DoD): proves that one
-- pharmacy's data is genuinely unreachable from another tenant's
-- credentials, and that the anon role cannot touch the tables directly.
--
-- Plan 11-H upgrades (2026-08-05, staff-engineer review): the gate must
-- assert, not assume, the post-0003 schema, must exercise the app's real
-- payload shape (party ids), and must be self-cleaning so gate runs stop
-- leaving residue on the pilot backend.
--
-- How to run:
--   1. Apply supabase/migrations/0001_pharmacy_schema.sql first.
--   2. Apply supabase/migrations/0002_expense_category.sql (PLANS/10:
--      the expense/category type is tested below — the whitelist must
--      accept BOTH the historical `cash_draw` and the current `expense`).
--   3. Apply supabase/migrations/0003_ledger_party_reference_fks.sql
--      (Plan 11-H: section 8 asserts the post-0003 FK count, and section 9
--      pushes a realistic app payload with party ids — these FAIL if 0003
--      is not applied).
--   4. Paste this whole file into the Supabase SQL editor and run, or run
--      `supabase test db` if the CLI is linked.
--   5. Passing = no error output; the script raises on any failed check.
--      Record the result in PROJECT_MEMORY.md / SECURITY.md (VERIFIED line).
--
-- Self-cleaning (section 10): every row this script creates (sections 1-9)
-- is deleted at script end, along with e2e residue from
-- test_live/rls_isolation_test.dart (`live-test-%` pharmacies — anon has
-- no delete grants, so the SQL gate, which runs with owner privilege, is
-- the cleanup vehicle for the whole deploy gate). A gate run leaves the
-- pilot backend exactly as it found it.

do $$
declare
  pharmacy_a bigint;
  pharmacy_b bigint;
  v_count bigint;
  a_tok constant text := 'test-token-a-' || md5(random()::text);
  b_tok constant text := 'test-token-b-' || md5(random()::text);
  uuid_a constant text := md5('uuid-a-' || random()::text);
  uuid_b constant text := md5('uuid-b-' || random()::text);
  -- Section 9 identity: dedicated disposable tenant, distinct from the
  -- random a/b tenants so the real-payload section is recognizable in any
  -- residue report.
  gate_tok constant text := 'test-token-gate-' || md5(random()::text);
  -- >= 16 chars: register_device rejects shorter uuids (verified live
  -- 2026-08-05 — 'rls-gate-uuid' at 13 chars was refused).
  gate_uuid constant text := 'rls-gate-uuid-0001';
  gate_pharmacy bigint;
begin
  -- 1) Registration works for the anon role (granted execute only).
  set local role anon;
  select public.register_device(a_tok, uuid_a, 'pharmacy-a', 'EGP')
    into pharmacy_a;
  reset role;
  assert pharmacy_a is not null, 'FAIL: register_device returned null';
  raise notice 'ok: anon can register device (pharmacy %)', pharmacy_a;

  -- 2) Direct table access is denied to anon on every data table.
  set local role anon;
  begin
    perform count(*) from public.ledger_entries;
    raise exception 'FAIL: anon could select ledger_entries';
  exception when insufficient_privilege then
    raise notice 'ok: anon select on ledger_entries denied';
  end;
  begin
    perform count(*) from public.pharmacies;
    raise exception 'FAIL: anon could select pharmacies';
  exception when insufficient_privilege then
    raise notice 'ok: anon select on pharmacies denied';
  end;
  begin
    perform count(*) from public.products;
    raise exception 'FAIL: anon could select products';
  exception when insufficient_privilege then
    raise notice 'ok: anon select on products denied';
  end;
  begin
    perform count(*) from public.devices;
    raise exception 'FAIL: anon could select devices';
  exception when insufficient_privilege then
    raise notice 'ok: anon select on devices denied';
  end;
  begin
    insert into public.ledger_entries
      (id, pharmacy_id, type, amount_minor, occurred_at)
    values (99999, pharmacy_a, 'sale', 1, now());
    raise exception 'FAIL: anon could insert into ledger_entries directly';
  exception when insufficient_privilege then
    raise notice 'ok: anon direct insert on ledger_entries denied';
  end;
  reset role;

  -- 3) Push via token A lands exactly in pharmacy A, with correct count.
  --    Both whitelisted types are exercised: the historical `cash_draw`
  --    (pre-plan-10 remote rows keep that value forever) and the current
  --    `expense` with its category (0002_expense_category.sql).
  set local role anon;
  select public.push_ledger_entries(a_tok, jsonb_build_array(
    jsonb_build_object(
      'id', 1, 'type', 'cash_draw', 'amount_minor', 500,
      'occurred_at', '2026-08-02T10:00:00Z', 'note', 'draw'
    ),
    jsonb_build_object(
      'id', 2, 'type', 'expense', 'amount_minor', 1250,
      'category', 'owner_draw',
      'occurred_at', '2026-08-02T10:05:00Z', 'note', 'rent'
    )
  )) into v_count;
  reset role;
  assert v_count = 2, 'FAIL: expected 2 rows inserted for pharmacy A';
  select count(*) into v_count
  from public.ledger_entries where pharmacy_id = pharmacy_a;
  assert v_count = 2, 'FAIL: pharmacy A row count mismatch';

  -- 3b) The expense row persisted its category.
  select count(*) into v_count
  from public.ledger_entries
  where pharmacy_id = pharmacy_a
    and id = 2
    and type = 'expense'
    and category = 'owner_draw';
  assert v_count = 1, 'FAIL: expense category not persisted';

  -- 3c) An invalid category is refused by the CHECK constraint.
  set local role anon;
  begin
    perform public.push_ledger_entries(a_tok, jsonb_build_array(
      jsonb_build_object(
        'id', 3, 'type', 'expense', 'amount_minor', 100,
        'category', 'bogus', 'occurred_at', '2026-08-02T10:06:00Z'
      )
    ));
    raise exception 'FAIL: invalid expense category was accepted';
  exception when others then
    if sqlerrm like '%check%' then
      raise notice 'ok: invalid expense category refused';
    else
      raise;
    end if;
  end;
  reset role;

  -- 4) Idempotent retry: pushing the same local ids again inserts nothing.
  set local role anon;
  select public.push_ledger_entries(a_tok, jsonb_build_array(
    jsonb_build_object(
      'id', 1, 'type', 'cash_draw', 'amount_minor', 500,
      'occurred_at', '2026-08-02T10:00:00Z'
    )
  )) into v_count;
  reset role;
  assert v_count = 0, 'FAIL: duplicate push inserted rows';

  -- 5) Tenant B is fully isolated from tenant A. Same local ids, same
  --    payload shape — but B's rows must land only in pharmacy B.
  set local role anon;
  select public.register_device(b_tok, uuid_b, 'pharmacy-b', 'EGP')
    into pharmacy_b;
  reset role;
  assert pharmacy_b is not null and pharmacy_b <> pharmacy_a,
    'FAIL: tenant B did not get its own pharmacy';

  set local role anon;
  select public.push_ledger_entries(b_tok, jsonb_build_array(
    jsonb_build_object(
      'id', 1, 'type', 'sale', 'amount_minor', 99,
      'occurred_at', '2026-08-02T10:10:00Z'
    )
  )) into v_count;
  reset role;

  select count(*) into v_count
  from public.ledger_entries where pharmacy_id = pharmacy_a;
  assert v_count = 2, 'FAIL: tenant B write reached tenant A';
  select count(*) into v_count
  from public.ledger_entries where pharmacy_id = pharmacy_b;
  assert v_count = 1, 'FAIL: tenant B rows missing';
  raise notice 'ok: tenant isolation holds across pharmacies';

  -- 6) Register-first-wins: the same uuid with a different token is refused.
  set local role anon;
  begin
    perform public.register_device(
      'test-token-c-' || md5(random()::text), uuid_a, 'pharmacy-a', 'EGP'
    );
    raise exception 'FAIL: uuid re-registration with a different token succeeded';
  exception when others then
    if sqlerrm like '%already registered%' then
      raise notice 'ok: duplicate uuid registration refused';
    else
      raise;
    end if;
  end;
  reset role;

  -- 7) Unknown tokens are refused, not silently accepted.
  set local role anon;
  begin
    perform public.push_ledger_entries(
      'test-token-unknown', jsonb_build_array(
        jsonb_build_object(
          'id', 1, 'type', 'sale', 'amount_minor', 1,
          'occurred_at', '2026-08-02T10:00:00Z'
        )
      )
    );
    raise exception 'FAIL: unknown token was accepted';
  exception when others then
    if sqlerrm like '%unknown device token%' then
      raise notice 'ok: unknown token refused';
    else
      raise;
    end if;
  end;
  reset role;

  -- 8) Post-0003 schema assertion (Plan 11-H): ledger_entries must have
  --    exactly ONE remaining FK — the pharmacy_id tenant key. The four
  --    party-reference FKs (product/supplier/customer/profile) are gone.
  --    This asserts the migration applied; it does not assume it.
  select count(*) into v_count
  from pg_constraint
  where conrelid = 'public.ledger_entries'::regclass
    and contype = 'f';
  assert v_count = 1,
    'FAIL: expected exactly 1 FK on ledger_entries after 0003, found ' || v_count;
  raise notice 'ok: ledger_entries FK count = % (0003 applied)', v_count;

  -- 9) Real app payload shape (Plan 11-H): the app always sends party ids
  --    — a sale carries product_id + profile_id, an expense carries
  --    profile_id + category. Before 0003 these pushes failed with 409
  --    23503 (Key (product_id)=(1) is not present in table "products"),
  --    reproduced live on 2026-08-05. Now they must persist VALUES, not
  --    just count.
  set local role anon;
  select public.register_device(gate_tok, gate_uuid, 'pharmacy-gate', 'EGP')
    into gate_pharmacy;
  reset role;
  assert gate_pharmacy is not null, 'FAIL: gate tenant registration failed';

  set local role anon;
  select public.push_ledger_entries(gate_tok, jsonb_build_array(
    jsonb_build_object(
      'id', 101, 'type', 'sale', 'amount_minor', 1500,
      'product_id', 1, 'profile_id', 1,
      'occurred_at', '2026-08-05T11:00:00Z', 'note', 'real-shape sale'
    ),
    jsonb_build_object(
      'id', 102, 'type', 'expense', 'amount_minor', 300,
      'profile_id', 1, 'category', 'rent',
      'occurred_at', '2026-08-05T11:01:00Z', 'note', 'real-shape expense'
    )
  )) into v_count;
  reset role;
  assert v_count = 2, 'FAIL: real-shape push did not insert 2 rows';

  select count(*) into v_count
  from public.ledger_entries
  where pharmacy_id = gate_pharmacy
    and id = 101
    and type = 'sale'
    and amount_minor = 1500
    and product_id = 1
    and profile_id = 1;
  assert v_count = 1, 'FAIL: real-shape sale values not persisted';
  select count(*) into v_count
  from public.ledger_entries
  where pharmacy_id = gate_pharmacy
    and id = 102
    and type = 'expense'
    and amount_minor = 300
    and profile_id = 1
    and category = 'rent';
  assert v_count = 1, 'FAIL: real-shape expense values not persisted';
  raise notice 'ok: real app payload shape persists with party ids';

  -- 10) Self-cleaning sweep: this script's own tenants (a, b, gate) and
  --     e2e residue from test_live runs (`live-test-%` pharmacies — anon
  --     cannot delete them; the deploy gate runs both, so the SQL gate is
  --     the cleanup vehicle). Deletes are owner-privileged, keyed on
  --     gate-generated identifiers only — never on real data.
  delete from public.ledger_entries
  where pharmacy_id in (pharmacy_a, pharmacy_b, gate_pharmacy)
    or pharmacy_id in (
      select p.id from public.pharmacies p
      where p.uuid like 'live-test-%'
    );
  delete from public.devices
  where pharmacy_id in (pharmacy_a, pharmacy_b, gate_pharmacy)
    or pharmacy_id in (
      select p.id from public.pharmacies p
      where p.uuid like 'live-test-%'
    );
  delete from public.pharmacies
  where id in (pharmacy_a, pharmacy_b, gate_pharmacy)
    or uuid like 'live-test-%';
  raise notice 'ok: gate residue swept (a, b, gate, live-test-*)';

  raise notice 'ALL RLS ISOLATION CHECKS PASSED';
end $$;
