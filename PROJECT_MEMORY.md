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
Plan 02 (local identity and access) is complete: onboarding creates
pharmacy + owner atomically and offline; per-profile optional 4-digit PIN
(salted SHA-256 hash in `flutter_secure_storage` under
`pin_hash_<profileId>`, only the key reference in the DB's
`UserProfiles.pin_hash_ref`); profile switcher adds family profiles and
switches the active profile (PIN-gated when set); active profile
persisted (`last_active_profile_id` in secure storage) and attributed via
`activeProfileProvider`; forgot-PIN wipes local identity and re-onboards
(no recovery, stated in-app). Drift tables live in `lib/core/data/tables/`
(shared core layer, not inside the feature — plan 03's ledger tables will
follow the same home). Profile switch navigates with `go()`, not `pop()`
(go_router has no back stack after `go()`). `test/widget_test.dart` covers
RTL boot smoke; `test/features/identity/` covers the repository and the
full identity flows.
Plan 03 (data + sync) is next. See `FEATURES.md` for per-plan status.

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
