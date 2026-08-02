# Security — Pharmacy Profit Control Platform

## Actual threat model
This app holds a small business's complete financial history: sales,
cost/margin data, supplier debt, customer debt, and cash-draw records for
one pharmacy per install. Realistic threats: device theft/loss exposing
local financial data; a compromised or misconfigured backend exposing one
pharmacy's data to another tenant (multi-tenant SaaS); not, at this stage,
targeted attacks — this is a small-business tool, not a high-value target,
but the data is sensitive to its owner and the product's entire value
proposition depends on it being trustworthy and available.

## Controls in place
- **Auth:** none server-side in P0 — local device profile with an
  optional PIN (hash in `flutter_secure_storage`, never plaintext, never
  in the `drift` DB itself). Real Supabase Auth deferred until a
  multi-device/employee need is confirmed — see `DECISIONS.md`.
- **Storage:** local `drift` database encrypted at rest via `sqlcipher`.
  Explicit decision, not silence, per `SECURITY_STANDARDS.md`'s
  requirement — justified given the data is a full financial history.
- **Network:** TLS to Supabase (managed). No certificate pinning in P0 —
  proportionate call; revisit if/when card payment data ever flows through
  the app directly (it shouldn't — see `PROJECT_MEMORY.md` monetization
  note).
- **Authorization:** enforced server-side via Postgres Row-Level Security
  scoped to `pharmacy_id`, configured from the first migration even though
  P0 has no multi-user backend access yet — not retrofitted onto live
  tenant data later.
- **Backup write path (plan 03):** the only server surface anon can reach
  is two SECURITY DEFINER functions, `register_device` and
  `push_ledger_entries`; ALL table privileges (select/insert/update/
  delete) are revoked from anon/authenticated, RLS is enabled on every
  table, and there are no direct-table policies. Backup auth is a
  per-install random 256-bit device token in `flutter_secure_storage`
  (`device_token_v1`); the server stores only its SHA-256 hex in
  `devices` (never the token). The tenant is derived from the token hash,
  never from the payload. Registration is register-first-wins on the
  pharmacy uuid. The ledger is append-only server-side too: the push
  function only ever inserts, keyed on the composite
  `(pharmacy_id, id)` with `ON CONFLICT DO NOTHING` (idempotent retries),
  and no update/delete grants exist. Verified live against the project:
  direct anon select/insert on all tables denied, cross-token isolation
  holds, unknown tokens and duplicate-uuid registrations refused.
- **Secrets handling:** `.gitignore` confirmed to cover signing keys and
  any Supabase service keys before first commit (`PLANS/
  01_PROJECT_FOUNDATION_PLAN.md` step 8). Supabase credentials for live
  verification live only in the gitignored `.env.local` and are passed
  per-run via `--dart-define`, never committed (`test_live/` is outside
  `test/` so CI can never run it without credentials).

## Explicitly accepted risks
- No certificate pinning — no sensitive payment traffic in this app yet.
- No server-side auth in P0 — accepted because the confirmed pilot persona
  is single-device/single-owner; revisit the moment that's no longer true.
- No real-time multi-device conflict resolution — accepted for the same
  reason; a data-loss/inconsistency risk only if the single-device
  assumption breaks before this is built.
- The anon key is extractable from the APK by design; defense is the RPC
  layer, so exposure only enables what anon can already do.
- No rate limiting on `register_device`/`push_ledger_entries` — a
  motivated attacker with the anon key could fill disk with phantom
  tenants; accepted for the pilot (single real tenant, low traffic) —
  revisit before any wider rollout (list as a plan 08 hardening item).
- Test tenants/rows created by the live verification cannot be deleted
  via the app (anon has no delete grants) — acceptable in a pilot
  project; use a throwaway project for repeatable verification.

## Last security-audit date
None yet — run the `security-audit` skill before the first release build
per `PLANS/08_TESTING_AND_RELEASE_HARDENING_PLAN.md`, and update this line
when it happens.
