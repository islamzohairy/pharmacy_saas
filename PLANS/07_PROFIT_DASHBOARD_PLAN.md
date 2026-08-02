# 07 — Unified Profit Dashboard Plan

## Objective
Build the screen that directly answers the product's positioning statement
(spec §5): "know where your money goes, who owes you, and who you owe."
This is the value-moment screen the whole MVP hypothesis (spec §10) is
built to prove.

## Scope
**Included:** single dashboard screen showing sales total, cost total,
draws total, net profit, total owed to suppliers, total owed by customers
— for a selectable date range (default: today; also this week/month).
**Excluded:** exportable reports, charts/trends beyond the current numbers
(spec §11 "reports beyond dashboard" is explicitly P1), any forecasting.

## Business Context
Spec §1: "she doesn't know where the money goes" is the single most
consistently confirmed problem. This screen is the direct answer, and
should be the app's default/home screen — not one tab among several.

## Technical Design
Pure read screen: calls `calculateProfit` and both balance calculators from
plan 04 with the selected date range, renders the results. No writes occur
on this screen. Given F3/plan 04's design, every number here is always
freshly derived from the ledger — this screen has zero risk of showing a
stale or silently-drifted balance, by construction.

## SOLID Application
The screen (presentation) has no calculation logic at all — it's a thin
render of what plan 04's pure functions return, called with a date-range
parameter selected by the user. This is the cleanest possible
demonstration of keeping business logic out of widgets, since there's
nothing here but display.

## File Structure Impact
**New:** `lib/features/dashboard/presentation/` (dashboard screen,
date-range selector widget).
**Modified:** `lib/app.dart` — dashboard becomes the default post-launch
route (after profile creation, plan 02).

## Implementation Steps
1. Build date-range selector (today / this week / this month, defaulting
   to today).
2. Wire dashboard screen to call `calculateProfit`,
   `calculateOwedToSupplier` (summed across all suppliers), and
   `calculateOwedByCustomer` (summed across all customers) for the
   selected range.
3. Render each figure with clear Arabic-first labeling (per
   `ENGINEERING_STRATEGY.md` §8) — the number alone isn't enough; the
   label must make unambiguous which figure is which, since these numbers
   are the product's core trust signal.
4. Set dashboard as the default post-onboarding route.
5. Implement loading/empty (no entries yet for the range)/error states.

## Dependencies
Requires `04_FINANCIAL_LEDGER_PLAN.md`. Benefits from plans 05-06 existing
(so there's real data to show) but has no hard code dependency on them.

## Testing Strategy
Widget tests verifying the dashboard renders correctly against a stubbed
set of plan 04 use-case results for each date range option, including the
empty-range case (zero entries → zero/empty state, not an error).

## Edge Cases
- First day of use, zero entries — must show a clear empty/onboarding-style
  state ("log your first sale to see your numbers here"), not a wall of
  zeros with no context.
- Date range spanning a period with only debt entries and no sales — profit
  figure should still compute correctly (zero sales, zero cost, draws
  still subtracted if any occurred).

## Security Considerations
None beyond plan 03's baseline — read-only screen.

## Performance Considerations
Relies entirely on plan 03's `(pharmacy_id, occurred_at)` index — verify
the "this month" range query stays fast as ledger history grows across
the pilot period; this is the query most likely to slow down first as data
accumulates.

## Acceptance Criteria
- Dashboard is the default screen after first-launch onboarding.
- All figures are correct against a hand-verified test dataset for each
  date-range option.
- Empty state is clear and actionable, not a blank/zero-filled screen.

## Builder AI Instructions
**Do:** keep this screen a pure consumer of plan 04's functions — no new
calculation logic.
**Do not:** cache or store any of these figures for reuse — always
recompute live from the ledger on screen load per date range, per plan
03/04's design.
**Common mistakes:** defaulting the date range to "this month" instead of
"today" — today matches the daily-logging habit the MVP hypothesis (spec
§10) is trying to prove, and should be the first thing she sees.
**Definition of done:** matches `DEFINITION_OF_DONE.md`; runtime-verify
against real logged data (products, sales, draws, debts) end-to-end, not
just against stubbed unit test data — this is the screen the entire
pilot's success is judged by.
