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
- **Secrets handling:** `.gitignore` confirmed to cover signing keys and
  any Supabase service keys before first commit (`PLANS/
  01_PROJECT_FOUNDATION_PLAN.md` step 8).

## Explicitly accepted risks
- No certificate pinning — no sensitive payment traffic in this app yet.
- No server-side auth in P0 — accepted because the confirmed pilot persona
  is single-device/single-owner; revisit the moment that's no longer true.
- No real-time multi-device conflict resolution — accepted for the same
  reason; a data-loss/inconsistency risk only if the single-device
  assumption breaks before this is built.

## Last security-audit date
None yet — run the `security-audit` skill before the first release build
per `PLANS/08_TESTING_AND_RELEASE_HARDENING_PLAN.md`, and update this line
when it happens.
