# 04 — Financial Ledger Plan

## Objective
Build the domain-layer logic that turns raw `ledger_entries` rows (plan 03)
into the four confirmed problems' actual behavior: cash draw logging,
supplier debt tracking, customer debt tracking, and the profit calculation
that feeds the dashboard (plan 07).

## Scope
**Included:** domain use-cases for recording a draw, recording
supplier/customer debt, recording a debt repayment; pure-function profit
calculation over the ledger; balance-owed calculations per supplier/
customer.
**Excluded:** the screens that call these use-cases (plans 05, 06, 07);
expiry alerting logic (P1, not yet confirmed per spec §10).

## Business Context
This is the direct engineering answer to the spec's four Tier 1 confirmed
problems (§1, §7): unclear money flow, supplier debt, cash draws mixed
with income, customer debt visibility. Everything here is pure calculation
over the append-only ledger from plan 03 — no feature-specific UI logic.

## Technical Design
Each recordable action (draw, supplier debt, customer debt, repayment) is
a use-case function: validate input → construct a `LedgerEntry` → call
`LedgerRepository.append()` (no other write path exists, per plan 03).
Profit and balance calculations are pure functions over a list of
`LedgerEntry`, independent of `drift`/Supabase — this is what keeps them
trivially unit-testable and keeps business logic out of widgets and out of
providers (`GLOBAL_RULES.md`).

`calculateProfit(entries, dateRange)` = sum(sale amounts) − sum(cost of
goods sold) − sum(cash draws), for entries in range. `calculateOwedTo
Supplier(entries, supplierId)` and `calculateOwedByCustomer(entries,
customerId)` = sum(debt entries) − sum(repayment entries) per party, always
computed live from the ledger, never from a stored/mutated field — this is
the concrete implementation of the F3 fix.

## SOLID Application
Use-cases and calculation functions are pure, single-purpose, and take
their dependencies (the repository interface) by injection — never
instantiate a concrete `drift` or Supabase class directly. This is what
makes them testable with an in-memory fake repository, no database
required for the test suite.

## File Structure Impact
**New:** `lib/features/ledger/domain/usecases/` (one file per action:
`record_draw.dart`, `record_supplier_debt.dart`,
`record_customer_debt.dart`, `record_repayment.dart`),
`lib/features/ledger/domain/calculations/` (`profit_calculator.dart`,
`balance_calculator.dart`).
**Modified:** none — this plan is additive on top of plan 03's repository.

## Implementation Steps
1. Implement each use-case as a pure function taking validated input +
   `activeProfileProvider`'s current profile (for attribution) → calls
   `LedgerRepository.append()`.
2. Implement `calculateProfit` and the two balance calculators as pure
   functions over `List<LedgerEntry>`.
3. Add input validation (non-negative amounts, valid party reference for
   debt entries) at the use-case boundary — reject before it reaches the
   repository, not after.
4. Unit test each use-case and calculation function in isolation with a
   fake in-memory repository.

## Dependencies
Requires `03_DATA_AND_SYNC_PLAN.md` (repository interfaces, schema) and
`02_IDENTITY_AND_ACCESS_PLAN.md` (`activeProfileProvider` for
attribution).

## Testing Strategy
Unit tests only at this layer — no widget/integration tests needed since
there's no UI here yet. Cover: correct profit calculation across a mixed
set of sale/draw/debt entries; correct balance-owed calculation with
partial repayments; rejection of negative/zero amounts; correct
attribution of the active profile to each new entry.

## Edge Cases
- A supplier/customer with zero entries — balance calculators must return
  zero, not error.
- A repayment larger than the outstanding debt (overpayment) — decide and
  document the behavior explicitly (allow, resulting in a negative
  balance = credit, rather than silently clamping to zero, which would
  lose information the owner might care about).
- Profit calculation over a date range with zero sales — must not divide
  by zero or crash; returns zero/empty state.

## Security Considerations
None beyond what plan 03 already covers — this layer has no direct
storage or network access.

## Performance Considerations
For P0 data volumes (§`ENGINEERING_STRATEGY.md` §7), in-memory calculation
over a bounded, indexed query result is fine. If dashboard queries ever
pull unbounded history, paginate/aggregate at the query level rather than
loading the full ledger into Dart to sum — not a P0 concern given expected
volumes, but state this assumption in `PROJECT_MEMORY.md` so it's revisited
if volumes grow.

## Acceptance Criteria
- Recording a draw, supplier debt, customer debt, or repayment produces
  exactly one new append-only `LedgerEntry`, correctly typed and
  attributed.
- `calculateProfit` and both balance calculators produce correct results
  against a hand-verified test dataset covering all five entry types.
- No use-case or calculation function has any direct `drift`/Supabase
  import.

## Builder AI Instructions
**Do:** keep every function in this plan pure and independently testable
without a real database.
**Do not:** compute or store a running balance anywhere — every balance is
always derived fresh from the ledger, per plan 03's design.
**Common mistakes:** clamping an overpayment/negative balance to zero
instead of representing it accurately; forgetting to attribute the active
profile to a new entry.
**Definition of done:** matches `DEFINITION_OF_DONE.md`; this is a
critical financial flow, so unit test coverage on the calculators is
non-negotiable, not "nice to have."
