# 06 — Cash Draw and Debt Tracking Plan

## Objective
Build the screens for the three remaining confirmed P0 problems (spec §1,
§10 items 4-6): owner cash draw logging, supplier debt tracking, customer
debt tracking — using the use-cases already built in plan 04.

## Scope
**Included:** cash draw logging screen; supplier list + debt entry +
repayment screen; customer list + debt entry + repayment screen; each
shows a live balance-owed figure from plan 04's calculators.
**Excluded:** purchase-order workflows, expense tracking beyond draws,
anything P1+ per spec §11.

## Business Context
These three screens directly answer three of the four things the real
interview subject named unprompted (spec §1): where cash draws go, who she
owes, who owes her. This is the highest-trust part of the product — the
numbers shown here must be exactly right, always.

## Technical Design
Three near-identical patterns sharing structure but not code (each is a
distinct feature per the OS's feature-first rule, no forced shared widget
abstraction until a real duplication shows up):
- **Draw:** amount + optional note → `recordDraw` use-case (plan 04).
- **Supplier debt:** select/create supplier → amount owed or repayment →
  `recordSupplierDebt`/`recordRepayment` (plan 04) → screen shows
  `calculateOwedToSupplier` live.
- **Customer debt:** identical shape for customers,
  `calculateOwedByCustomer`.

Each list screen (suppliers, customers) shows current balance per party,
sorted with non-zero balances first — this is the actual "who owes me /
who do I owe" answer the product exists to give.

## SOLID Application
Screens depend on plan 04's use-cases and calculators through their
interfaces only; no calculation logic duplicated into widgets.

## File Structure Impact
**New:** `lib/features/draws/presentation/`,
`lib/features/supplier_debt/{presentation,data}/`,
`lib/features/customer_debt/{presentation,data}/` (repository wiring for
`Supplier`/`Customer` entities from plan 03's schema).
**Modified:** none.

## Implementation Steps
1. Build draw logging screen (amount, optional note, confirm).
2. Build supplier list screen with live balance per supplier; supplier
   create flow; debt-entry and repayment sub-flows.
3. Build customer list screen with live balance per customer; customer
   create flow; debt-entry and repayment sub-flows.
4. All three wired to plan 04's use-cases/calculators — no new
   calculation logic written in this plan.
5. Implement all four UI states on each screen.

## Dependencies
Requires `03_DATA_AND_SYNC_PLAN.md` and `04_FINANCIAL_LEDGER_PLAN.md`.

## Testing Strategy
Widget tests per screen (form validation, balance display updates after a
new entry). No new unit tests needed for calculation logic — already
covered in plan 04; these tests should stub the use-cases rather than
re-testing them.

## Edge Cases
- Recording a repayment with no prior debt for that party — allowed (see
  plan 04's overpayment/credit handling) but the UI should make a
  resulting negative/credit balance clearly legible, not just a
  confusing negative number.
- Same supplier or customer name entered twice (typo duplicate) — no
  hard uniqueness constraint needed for P0 (real-world names repeat), but
  consider a simple "did you mean X?" prompt on create as a cheap UX
  improvement — not required for acceptance.
- Deleting a supplier/customer with a non-zero balance — block or warn;
  don't allow silent loss of an owed-money record.

## Security Considerations
None beyond plan 03's baseline.

## Performance Considerations
Supplier/customer lists with live balances must use the indexed ledger
query from plan 03 (`(pharmacy_id, type)`), not an unindexed full-table
scan per row rendered.

## Acceptance Criteria
- A draw, a supplier debt/repayment, and a customer debt/repayment can
  each be logged in a handful of taps.
- Supplier and customer lists show accurate, live balances that update
  immediately after a new entry.
- All screens handle empty (no suppliers/customers yet), loading, and
  error states.

## Builder AI Instructions
**Do:** reuse plan 04's use-cases and calculators exactly as-is — this
plan is UI only.
**Do not:** write any new balance-calculation logic in this plan; if the
existing calculators don't fit a screen's need, that's a signal to revisit
plan 04, not to duplicate logic here.
**Common mistakes:** clamping or hiding a negative/credit balance instead
of showing it accurately (see plan 04's edge-case decision).
**Definition of done:** matches `DEFINITION_OF_DONE.md`; these are
core-value, high-trust flows — runtime-verify each, don't rely on unit
tests alone.
