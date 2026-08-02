# 08 — Testing and Pilot Release Hardening Plan

## Objective
Close the gap between "each plan's tests pass individually" and "this is
safe to hand to a real pharmacy owner for daily use with her actual
money." This plan runs after plans 01-07 are individually complete.

## Scope
**Included:** full-suite regression run, end-to-end critical-flow
verification, RLS cross-tenant isolation test (plan 03), release build
validation, crash reporting wiring, a documented rollback/support plan for
the pilot.
**Excluded:** anything not already built in plans 01-07 — this plan
hardens, it doesn't add features.

## Business Context
This is a pilot with a real business owner's real financial records, not a
demo. `DEFINITION_OF_DONE.md`'s "runtime-verified for critical flows" bar
applies at full-app scope here, not per-plan.

## Technical Design
No new production code — this plan is verification, CI hardening, and
release configuration. Primary artifact: a signed, release-mode Android
build that has been exercised end-to-end via `mcp_flutter`/manual QA
through the full P0 flow (onboarding → product entry → sale → draw →
supplier debt → customer debt → dashboard) on a real or emulated device.

## SOLID Application
N/A — no new architecture surface introduced by this plan.

## File Structure Impact
**New:** `android/` signing config finalized, crash-reporting SDK wiring
(e.g., Firebase Crashlytics or equivalent), `PROJECTS/pharmacy-saas/
FEATURES.md` updated to reflect P0 shipped status.
**Modified:** CI config (plan 01) extended to run the full suite +
`flutter build apk --release` as a gate, not just debug-mode analyze/test.

## Implementation Steps
1. Run the full test suite across plans 01-07; fix any regressions
   surfaced by cross-plan interaction (e.g., plan 07's dashboard against
   plan 05/06's real screens, not just plan 04's stubbed use-cases).
2. Execute the RLS cross-tenant isolation test from plan 03 as a final
   explicit gate — this is the one test in the whole package that, if
   wrong, is a genuine data-breach risk across pilot customers once there
   is more than one.
3. Runtime-verify (via `mcp_flutter` or manual device testing) the full
   critical flow end-to-end, in Arabic/RTL, on the target Android
   configuration.
4. Configure release signing, confirm no debug-only bypasses (e.g.,
   disabled cert validation) remain — per `SECURITY_STANDARDS.md`'s
   AI-specific rule against shipping "temporary" test workarounds.
5. Wire crash reporting so a pilot-customer crash is visible to the team,
   not discovered secondhand.
6. Document a rollback plan: what happens if a release-mode bug is found
   mid-pilot (how to roll back, how to communicate to the pilot customer
   given she has no in-app support channel yet).
7. Update `PROJECTS/pharmacy-saas/FEATURES.md` and log a `DECISIONS.md`
   entry marking P0 as shipped, with any deliberately-deferred item
   (employee enforcement, expiry alerting, e-invoicing) noted explicitly
   so it isn't rediscovered as a surprise gap later.

## Dependencies
Requires all of `01`-`07` complete.

## Testing Strategy
This plan's testing strategy *is* the plan: full regression suite, RLS
isolation test, end-to-end critical-flow runtime verification, release
build smoke test. No unit-test-only sign-off is acceptable here.

## Edge Cases
Explicitly re-verify the edge cases already listed in plans 02-07 still
hold when exercised together in one continuous session (e.g., profile
switch mid-session while a sale is in progress) — cross-plan interaction
edge cases are the ones most likely to have been missed plan-by-plan.

## Security Considerations
This is the last gate before a real pharmacy's real financial data is at
stake — treat the RLS isolation test and the signing/secrets check as
blocking, not advisory.

## Performance Considerations
Confirm release-mode build performance (not just debug-mode, which can
mask jank) on the dashboard and product-picker screens specifically —
these are flagged as the two places most likely to show performance
issues first (plans 05, 07).

## Acceptance Criteria
- Full test suite passes in CI, including on a release build.
- RLS cross-tenant isolation explicitly verified, not assumed.
- End-to-end critical flow manually or MCP-verified on a real device in
  Arabic/RTL.
- Crash reporting live; rollback plan documented; `FEATURES.md`/
  `DECISIONS.md` updated.

## Builder AI Instructions
**Do:** treat this as a genuine gate — if any step fails, P0 is not done,
regardless of how many individual plans passed their own acceptance
criteria.
**Do not:** mark this plan complete based on debug-mode testing alone;
release-mode behavior must be checked directly.
**Common mistakes:** treating the RLS test as "already covered" because
plan 03 wrote one — re-run it here as the final gate, since schema or
policy drift across plans 04-07 could have silently broken it.
**Definition of done:** every line of `CORE_SYSTEM/DEFINITION_OF_DONE.md`
applies at full-app scope, plus this plan's own acceptance criteria above.
This is the plan that answers "is this actually ready for a real pharmacy
owner," not "did each piece pass in isolation."
