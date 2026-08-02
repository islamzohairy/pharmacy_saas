# Project Memory — Pharmacy Profit Control Platform

Durable facts a fresh agent session should know on arrival. Edit in place
when a fact changes.

## Product
Mobile-first business-management app for independent pharmacy owners in
Egypt. Confirmed pilot persona (n=1, real interview): solo/family-operated
pharmacy, shares shifts with her father, smartphone-only, no existing
digital tools, allows customer credit. Non-goal for now: employee-scale
operations (ICP-B), full accounting, customer-facing app, delivery,
insurance, or AI diagnosis — all explicitly out of scope regardless of
future evidence tier.

## Constraints
- **Platform:** Android only. iOS/device-mix is an open question, not a
  decided "no" — see the interview plan in the product spec.
- **Offline/online model:** local-first, best-effort one-way backup sync.
  No real-time sync, no multi-device conflict resolution.
- **Auth model:** none server-side in P0. Local device profile + optional
  PIN. `role` field exists on `UserProfile` but is not enforced.
- **Monetization:** not yet designed into the app — pricing/billing is out
  of scope for every plan in `PLANS/`. When it lands, route payments
  through a compliant Egyptian processor (Paymob/Fawry-style), never
  handle card data directly.
- **Language:** Arabic-primary, RTL. English not yet built.

## Current state
Plan 01 (project foundation) is complete: Android applicationId is
`com.skypiecode.pharmacy_saas`; feature-first folder tree with stub
screens for all seven P0 routes; Arabic-primary RTL l10n (gen-l10n, ARB
in `lib/core/l10n/arb/`); `drift` connection wired with SQLCipher
encryption (sqlite3 3.x hooks user-define — `sqlcipher_flutter_libs` is
obsolete and must not be added); Supabase client wired as configuration
only (read from `SUPABASE_URL`/`SUPABASE_ANON_KEY` `--dart-define`s,
empty by default — no credentials committed, no auth/data flows).
Plans 02-08 remain unbuilt. See `FEATURES.md` for per-plan status.

## Things intentionally NOT done (don't propose these as gaps)
- No backend authentication — deliberate, see `ARCHITECTURE.md` §Identity.
- No employee-role enforcement — the field exists, the behavior doesn't.
  Confirm demand before building (spec §10-11).
- No expiry alerting logic — the optional field exists on `Product` for
  exactly this reason; alerting logic ships once confirmed, not before.
- No real-time/multi-device sync — one-way backup only.
- No e-invoicing/ETA implementation — gated behind `COMPLIANCE.md`
  confirmation, not a normal backlog item.
- No iOS build — Android only this round.
