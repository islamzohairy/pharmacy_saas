# 02 — Identity and Access Plan

## Objective
Build the P0 "flexible pharmacy/user access model" (spec §10 item 1) as a
local, device-level profile system with a role field — not a backend
authentication system. See `ENGINEERING_REVIEW.md` F2 and
`ENGINEERING_STRATEGY.md` §6 for the reasoning.

## Scope
**Included:** local pharmacy profile creation (name, currency default),
local user profile with `role` enum (`owner` / `family` / `employee`),
optional PIN gate stored via `flutter_secure_storage`, shift-style profile
switcher (she vs. her father) with no server round-trip.
**Excluded:** backend accounts, login/password/OTP flows, server-side
session tokens, enforcement of `employee`-role restrictions (role is
captured, not yet enforced — spec §10, §11).

## Business Context
Directly implements the spec's own hedge pattern (§10: capture data now,
build behavior when confirmed) applied to access instead of expiry. The
confirmed persona (§6) is single-device, no employees — this plan matches
engineering effort to that evidence instead of building auth infrastructure
ahead of demand.

## Technical Design
`Pharmacy` and `UserProfile` are the first two entities in the local
`drift` schema (full schema in `03_DATA_AND_SYNC_PLAN.md`). On first
launch: create one `Pharmacy` and one `UserProfile(role: owner)` locally,
no network call. A lightweight profile switcher (not a login screen) lets
a second local profile (`role: family`) be added for the shared-shift
pattern (spec §6, §15) — switching sets an in-memory "active profile"
Riverpod provider that every later feature reads for attribution (who
logged this sale/draw), which is what gives the ledger (plan 04) real
per-entry accountability without needing real auth.

## SOLID Application
`UserProfile` and `Pharmacy` are plain domain entities with no
presentation or persistence knowledge (dependency direction:
presentation → domain ← data, never the reverse). The "active profile"
provider is the single source of truth other features depend on via
interface, not by reaching into this feature's internals — respects the
OS's no-cross-feature-internal-imports rule.

## File Structure Impact
**New:** `lib/features/identity/{presentation,domain,data}/` — profile
creation screen, profile switcher widget, `UserProfile`/`Pharmacy`
entities, `drift` table definitions, `activeProfileProvider`.
**Modified:** `lib/app.dart` to route first-launch to profile creation.

## Implementation Steps
1. Define `Pharmacy` and `UserProfile` `drift` tables (role as an enum
   column) per the schema in `03_DATA_AND_SYNC_PLAN.md`.
2. Build first-launch flow: create pharmacy + owner profile, no network.
3. Build the profile switcher (add family profile, switch active profile).
4. Build optional PIN setup/entry using `flutter_secure_storage` for the
   PIN hash — never store the PIN in plaintext or in the `drift` DB.
5. Implement `activeProfileProvider` (Riverpod) as the attribution source
   for later features.
6. Wire first-launch routing in `go_router`.

## Dependencies
Requires `01_PROJECT_FOUNDATION_PLAN.md` complete (folder structure,
`drift`/Supabase wiring, RTL foundation).

## Testing Strategy
Unit tests for profile creation and switching logic. Widget tests for the
PIN entry flow (correct PIN unlocks, incorrect PIN blocks, no PIN set
skips the gate). No integration test required yet — this isn't a
data-loss-risk flow on its own.

## Edge Cases
- App reopened with no profile yet (first-launch state) — must not crash,
  routes to creation.
- PIN set then forgotten — define a reset path now (e.g., re-onboard by
  wiping local profile) since there's no server-side recovery in P0; state
  this limitation explicitly in-app so it isn't a silent trap.
- Two profiles created but only one ever used — must not force a
  choice on every launch; remember the last-active profile.

## Security Considerations
PIN hash (not the PIN itself) in secure storage, per
`SECURITY_STANDARDS.md`. Role field is captured but must not be presented
in-app as an enforced restriction yet — an `employee` profile currently has
identical access to `owner`; do not let the UI imply otherwise, since that
would be a false security claim to a real user.

## Performance Considerations
Trivial — single-row reads on app launch.

## Acceptance Criteria
- First launch creates a pharmacy + owner profile with zero network calls.
- A second (family) profile can be added and switched to without a login
  screen.
- PIN gate, if set, blocks profile switch until correct PIN entered.
- Every later ledger entry (plan 04) can read the currently active
  profile for attribution.

## Builder AI Instructions
**Do:** keep this entirely local/offline — no Supabase Auth calls anywhere
in this plan.
**Do not:** build a login screen, password reset flow, or any server
session concept — that's explicitly out of scope until a real
multi-device/employee need is confirmed (see `ENGINEERING_STRATEGY.md`
§6).
**Common mistakes:** treating the `role` field as if it already restricts
anything — it doesn't yet; don't let UI copy claim otherwise.
**Definition of done:** matches `DEFINITION_OF_DONE.md`; explicitly note in
the final report that server-side auth/enforcement was deliberately not
built, per this plan's scope.
