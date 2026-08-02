-- Cross-tenant isolation test for the P0 backup path.
-- The single most important test in plan 03 (plan DoD): proves that one
-- pharmacy's data is genuinely unreachable from another tenant's
-- credentials, and that the anon role cannot touch the tables directly.
--
-- How to run:
--   1. Apply supabase/migrations/0001_pharmacy_schema.sql first.
--   2. Paste this whole file into the Supabase SQL editor and run, or run
--      `supabase test db` if the CLI is linked.
--   3. Passing = no error output; the script raises on any failed check.
--      Record the result in PROJECT_MEMORY.md / SECURITY.md (VERIFIED line).

do $$
declare
  pharmacy_a bigint;
  pharmacy_b bigint;
  v_count bigint;
  a_tok constant text := 'test-token-a-' || md5(random()::text);
  b_tok constant text := 'test-token-b-' || md5(random()::text);
  uuid_a constant text := md5('uuid-a-' || random()::text);
  uuid_b constant text := md5('uuid-b-' || random()::text);
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
  set local role anon;
  select public.push_ledger_entries(a_tok, jsonb_build_array(
    jsonb_build_object(
      'id', 1, 'type', 'cash_draw', 'amount_minor', 500,
      'occurred_at', '2026-08-02T10:00:00Z', 'note', 'draw'
    ),
    jsonb_build_object(
      'id', 2, 'type', 'sale', 'amount_minor', 1250,
      'occurred_at', '2026-08-02T10:05:00Z'
    )
  )) into v_count;
  reset role;
  assert v_count = 2, 'FAIL: expected 2 rows inserted for pharmacy A';
  select count(*) into v_count
  from public.ledger_entries where pharmacy_id = pharmacy_a;
  assert v_count = 2, 'FAIL: pharmacy A row count mismatch';

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

  raise notice 'ALL RLS ISOLATION CHECKS PASSED';
end $$;
