-- 0002_expense_category.sql
-- PLANS/10 Phase 1 remote side: expenses with categories (ledger type
-- `expense` + a `category` column), plus the CHECK/whitelist updates so
-- push_ledger_entries accepts the new type.
--
-- Requires 0001_pharmacy_schema.sql already applied. New file on purpose:
-- 0001 is already applied to the live project, so editing it in place
-- changes nothing there and silently desyncs the repo from reality.
--
-- Sequencing (DECISIONS.md / PLANS/10): this migration MUST be applied to
-- the live project and push_ledger_entries confirmed working BEFORE any
-- client build that sends `expense` reaches a device. The Phase 0
-- wire-format fix alone is safe against the unmodified schema (it sends
-- `cash_draw`, already whitelisted); the enum rename is not.

-- Type CHECK refresh. 0001's constraint was anonymous inline
-- `check (type in (...))`, which Postgres auto-named
-- `ledger_entries_type_check`. It must be dropped and re-created to admit
-- `expense` — and must KEEP `cash_draw`: already-synced historical remote
-- rows carry that value forever (no restore/backfill path yet), and a
-- re-created CHECK without it would fail on existing rows. Deliberate,
-- documented gap (PLANS/10 §Phase 1).
alter table public.ledger_entries
  drop constraint ledger_entries_type_check;
alter table public.ledger_entries
  add constraint ledger_entries_type_check
  check (type in (
    'sale', 'cash_draw', 'expense',
    'supplier_debt', 'customer_debt', 'debt_repayment'
  ));

-- Category column: nullable (only expense rows set it), same snake_case
-- wire contract as everything else.
alter table public.ledger_entries
  add column category text
  check (category in ('owner_draw', 'rent', 'utilities', 'supplies', 'other'));

-- push_ledger_entries: accept `expense`, keep `cash_draw` (historical),
-- and thread `category` through the same nullif(...) optional-field
-- pattern already used for product_id/supplier_id/customer_id/profile_id.
create or replace function public.push_ledger_entries(
  p_token text,
  p_entries jsonb
) returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pharmacy_id bigint;
  v_entry jsonb;
  v_inserted int := 0;
begin
  select d.pharmacy_id into v_pharmacy_id
  from public.devices d
  where d.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');

  if v_pharmacy_id is null then
    raise exception 'unknown device token';
  end if;
  if p_entries is null or jsonb_typeof(p_entries) <> 'array' then
    raise exception 'p_entries must be a jsonb array';
  end if;

  for v_entry in select * from jsonb_array_elements(p_entries) loop
    if (v_entry ->> 'id') is null then
      raise exception 'entry missing id';
    end if;
    if (v_entry ->> 'type') not in (
      'sale', 'cash_draw', 'expense',
      'supplier_debt', 'customer_debt', 'debt_repayment'
    ) then
      raise exception 'unknown entry type: %', v_entry ->> 'type';
    end if;
    if (v_entry ->> 'amount_minor') is null
       or (v_entry ->> 'amount_minor')::bigint < 0 then
      raise exception 'invalid amount_minor';
    end if;
    if (v_entry ->> 'occurred_at') is null then
      raise exception 'entry missing occurred_at';
    end if;

    insert into public.ledger_entries (
      id, pharmacy_id, type, amount_minor,
      product_id, supplier_id, customer_id, profile_id,
      category, occurred_at, note
    )
    values (
      (v_entry ->> 'id')::bigint,
      v_pharmacy_id,
      v_entry ->> 'type',
      (v_entry ->> 'amount_minor')::bigint,
      nullif(v_entry ->> 'product_id', '')::bigint,
      nullif(v_entry ->> 'supplier_id', '')::bigint,
      nullif(v_entry ->> 'customer_id', '')::bigint,
      nullif(v_entry ->> 'profile_id', '')::bigint,
      nullif(v_entry ->> 'category', ''),
      (v_entry ->> 'occurred_at')::timestamptz,
      v_entry ->> 'note'
    )
    on conflict (pharmacy_id, id) do nothing;

    if found then
      v_inserted := v_inserted + 1;
    end if;
  end loop;

  return v_inserted;
end $$;