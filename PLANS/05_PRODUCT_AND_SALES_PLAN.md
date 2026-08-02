# 05 — Product Entry and Sales Entry Plan

## Objective
Build the two screens that generate the real numbers everything else
depends on (spec §10 items 2-3): lightweight product entry and simple
sales entry.

## Scope
**Included:** product create/edit screen (name, cost price, sell price,
optional expiry date), sales entry screen (pick product(s), quantity,
confirm sale → writes a `sale` ledger entry per plan 04).
**Excluded:** batch tracking, barcode scanning, inventory-level stock
counts — all correctly deferred per spec §10-11 pending Tier 3
confirmation.

## Business Context
Without real product and sale data flowing in daily, the profit dashboard
(plan 07) has nothing to show and the MVP's core hypothesis (spec §10:
"prove she'll start logging money daily") can't be tested at all. This is
the highest-frequency-use screen in the app and should be optimized for
speed of entry above all else.

## Technical Design
`ProductRepository` (plan 03) backs a simple list + create/edit form.
Sales entry: select one or more products with quantity → for each line,
call `recordSale` (a use-case following the same pattern as plan 04's
other actions, added here since it's sales-specific: constructs a `sale`
`LedgerEntry` with `amount_minor = sell_minor * quantity`, referencing
`product_id`). Cost basis for profit (plan 04's `calculateProfit`) is read
from the product's `cost_minor` at calculation time, not duplicated into
the ledger row — the ledger stores what happened (the sale amount), not a
derived number.

## SOLID Application
`recordSale` is a pure use-case, same shape as plan 04's actions —
presentation layer only collects input and calls it, no calculation logic
lives in the widget.

## File Structure Impact
**New:** `lib/features/products/{presentation,domain,data}/` (product
list/form screens, `ProductRepository` implementation wiring),
`lib/features/sales/{presentation,domain}/` (sales entry screen,
`record_sale.dart` use-case).
**Modified:** none.

## Implementation Steps
1. Build product list screen (reads `ProductRepository`) and create/edit
   form — expiry date field present, clearly optional, no validation
   forcing it.
2. Implement `recordSale` use-case per Technical Design above.
3. Build sales entry screen: product picker (searchable list, given
   pharmacies can carry hundreds of SKUs), quantity input, running total,
   confirm action.
4. Wire both screens into `go_router` from plan 01's stubs.
5. Ensure both screens implement all four UI states (loading/data/empty/
   error) per `FLUTTER_STANDARDS.md` — empty state on sales entry matters
   specifically: "no products yet" should route directly to product
   creation, not a dead end.

## Dependencies
Requires `03_DATA_AND_SYNC_PLAN.md` and `04_FINANCIAL_LEDGER_PLAN.md`.

## Testing Strategy
Unit tests for `recordSale`. Widget tests for the product form (validation:
cost/sell price required and non-negative; expiry truly optional) and the
sales entry flow (quantity validation, total calculation display). No
integration test required — not classified as data-loss-risk beyond what
plan 03's ledger tests already cover.

## Edge Cases
- Selling a product with no cost price set (data entry gap) — decide
  explicitly: block the sale, or allow it and flag the profit calculation
  as incomplete for that entry. Recommend blocking with a clear message,
  since a silent profit miscalculation is worse than a five-second product
  fix.
- Very long product list (hundreds of SKUs) — searchable/filterable list,
  not a raw unpaginated scroll.
- Sale of a product later deleted — products should be soft-deactivated,
  never hard-deleted, so historical ledger entries retain a valid
  `product_id` reference.

## Security Considerations
None beyond plan 03's baseline — no new sensitive data class introduced.

## Performance Considerations
Product picker must stay responsive at realistic pharmacy SKU counts
(hundreds) — use an indexed/filtered query, not an in-memory filter over
an unbounded `ListView`.

## Acceptance Criteria
- A product can be created with cost/sell price and optional expiry in
  under 15 seconds of interaction.
- A sale can be recorded against one or more products and produces
  correctly-typed, correctly-amounted `sale` ledger entries.
- Empty/loading/error states are present and correct on both screens.

## Builder AI Instructions
**Do:** optimize the sales entry flow for speed — this is used many times
a day.
**Do:** soft-deactivate products rather than hard-deleting them.
**Do not:** hard-delete a product that has any associated ledger history.
**Common mistakes:** making the expiry field feel required through
placeholder/validation copy when it must stay optional per spec §10.
**Definition of done:** matches `DEFINITION_OF_DONE.md`; both screens
runtime-verified (not just unit-tested) since sales entry is a
high-frequency core-value flow.
