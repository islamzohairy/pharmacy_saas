# Staff Engineer → Builder AI: Plan 12 Detailed Implementation Plan

One correction to the handoff record before the plan: Revision 3 §5 states inventory engagement is observable via activity history "with zero new instrumentation." That is true **from Plan 13 onward, not Plan 12** — the activity feed currently reads only ledger entries, and merging stock movements into it is a feed change I am explicitly sequencing into Plan 13 (where movement volume actually begins). No pilot-visible gap results, since Plans 12–14 all land before the pilot build. Recorded below as Decision D2 so it cannot fall between plans.

---

# PLANS/12_INVENTORY_FOUNDATION_PLAN.md

**Plan:** 12 — Inventory Foundation (Basic Inventory pillar, increment 1 of 3)
**Owner:** Staff Engineer AI · **Executor:** Builder AI (single execution cycle)
**Dependencies:** Plans 01–11-H on `main` (schema v6, 199 tests green baseline)
**Remote impact:** **None.** Local-only. Zero changes under `supabase/`, to the sync layer, or to any SECURITY DEFINER surface.

## 1. Objective

Introduce the stock-quantity primitive the catalog currently lacks, using the **append-only movement ledger** confirmed by the product owner in Revision 3: immutable stock movements (`initial`, `stock_in`, `stock_out`, `adjustment`), with on-hand quantity **always computed live by aggregation — never stored as a mutable counter**. Plan 12 delivers the foundation only: schema, domain, repository, calculator, initial-stock capture on the product form, and on-hand display in the product list. Sale-triggered deduction and manual adjustment UI are Plan 13; low-stock signals and the expense-category insight are Plan 14.

**Why this shape:** the project's foundational invariant — *never mutate a running total; append and aggregate* — exists because a shared-device shift-handoff makes mutable balances unsafe. Stock is the same class of balance. A movement log is a correctness mechanism, not analytics; analytics remains out of scope (§4.4).

## 2. Scope

**Included:**
- Phase 0 repository verification gate (read-only).
- Drift schema **v7**: new `stock_movements` table + migration, with the standing **migration rehearsal** (fixture + emulator runtime pass, both recorded in `DECISIONS.md`).
- `inventory` feature: domain entities, repository interface, on-hand calculator, data implementation, providers — exposed via a feature barrel.
- Product form: optional **initial stock** field at product creation → posts an `initial` movement.
- Product list: live **on-hand display** per product, negative values displayed gracefully.
- `DECISIONS.md` entries D1–D5 below; standard `FEATURES.md` / `PROJECT_MEMORY.md` closure updates.

**Excluded (do not let scope creep in):**
- Sale-triggered `stock_out`, the auto-deduct pharmacy setting, manual adjustment UI → **Plan 13**.
- Activity-feed merge for stock movements → **Plan 13** (Decision D2).
- Low-stock / "needs attention" signals, highest-expense-category insight → **Plan 14**.
- Any sync/remote work: no remote table, no `push_ledger_entries` change, no RLS change, no quarantine interaction. Stock movements never leave the device in P0.
- Barcode, purchase orders, batch tracking, reorder suggestions, movement analytics, fractional quantities.
- Any change to the financial ledger, profit calculation, or money handling.

## 3. Confirmed Decisions (record verbatim in `DECISIONS.md`)

- **D1 — Stock model:** append-only `stock_movements` ledger; on-hand = live aggregate. Movements are never updated or deleted; a correction is a new offsetting movement (same rule as the financial ledger).
- **D2 — Activity feed:** stock movements merge into the activity history in **Plan 13**, not Plan 12. Plan 12's only movement type is `initial` (one per product, low signal); Plan 13 is where movement volume begins. The pilot build ships after Plan 14, so no user-visible gap exists.
- **D3 — Negative stock: allowed, displayed gracefully.** On-hand may go negative (selling before a restock is logged). Never clamp, never block a sale — the recording loop is Tier-1 behavior and must not depend on inventory state. Negative on-hand is displayed in a distinct visual state with correct Arabic negative formatting. Rationale consistent with the existing never-clamp precedent (supplier overpayment shows as credit, `رصيد دائن`).
- **D4 — Units:** plain **integer units** (no minor units, no fractions). Fractional stock is a future evidence-gated decision.
- **D5 — Placement:** `stock_movements` drift table lives in `lib/core/data/tables/` (multiple features will read/write it — products now, sales in Plan 13 — per the 2026-08-02 cross-feature-tables precedent); domain/data/presentation live in a new `inventory` feature consumed through its barrel.

## 4. Phase 0 — Verification Gate (read-only; no code changes)

Builder verifies and records findings before editing anything:

| # | Check | Pass criteria |
|---|---|---|
| V1 | Current drift `schemaVersion` | == 6 (`sync_quarantine` from Plan 11-H); confirms v7 is the next slot |
| V2 | Table registration pattern | `app_database.dart` table list + `onUpgrade` ladder located; core-owned tables in `lib/core/data/tables/` |
| V3 | Product form structure | Creation flow located; money-entry parsing path identified (`core/format/money.dart`, `parseEgpToMinor`) incl. Arabic-Indic digit handling — determine whether digit normalization is extractable for integer quantity parsing or needs a small shared helper |
| V4 | Product list provider | Watch/stream pattern identified for adding an on-hand column without N+1 queries |
| V5 | Barrel patterns | `products.dart` / `ledger.dart` barrels confirmed as the import mechanism; no cross-feature internal imports anywhere in new code |
| V6 | Sync layer untouched | Confirm `stock_movements` appears nowhere in sync job/scheduler code paths after implementation (negative check at the end, listed here as intent) |

**Stop conditions (Major Change Rule):** if V1 shows a schema version other than 6, or V3 reveals `double` anywhere in the existing money/quantity paths → stop and report; do not fix inline.

## 5. Technical Design

### 5.1 Schema (drift v7, additive-only)

```
stock_movements
  id            INTEGER PRIMARY KEY AUTOINCREMENT
  pharmacy_id   INTEGER NOT NULL  (per-pharmacy isolation on every query)
  product_id    INTEGER NOT NULL
  movement_type TEXT NOT NULL CHECK in ('initial','stock_in','stock_out','adjustment')
  quantity      INTEGER NOT NULL  (signed delta: positive adds, negative subtracts)
  occurred_at   INTEGER (epoch) NOT NULL
  profile_id    INTEGER NULL      (caller-resolved attribution, plan-04 precedent)
  note          TEXT NULL
Index: (pharmacy_id, product_id) — aggregation hot path
```

Migration v6→v7: create table + index only. Nothing else. `0001`/`0002` remote migrations untouched; **no new remote migration exists for this plan**.

### 5.2 Domain (`lib/features/inventory/`)

- `StockMovement` entity; `StockMovementType` enum with snake_case `wireName`s (`initial`, `stock_in`, `stock_out`, `adjustment`) — convention maintained even though local-only, per the Plan 10 wireName lesson.
- `StockRepository` interface:
  - `recordMovement({pharmacyId, productId, type, quantity, profileId, note, occurredAt})` — append-only; takes plain ids resolved by the caller (plan-04 precedent; no provider/feature imports in domain).
  - `watchAllOnHand(pharmacyId)` → stream of `Map<productId, onHand>` — single grouped aggregate query (`SELECT product_id, SUM(quantity) … GROUP BY product_id`), **not** per-product queries.
  - `watchOnHand(pharmacyId, productId)` → stream<int>.
  - `getMovements(pharmacyId, productId)` → ordered history (used by tests now; adjustment UI in Plan 13).
- Pure on-hand reducer over a movement list — unit-testable business rules independent of drift.
- Barrel `inventory.dart` exports the feature's public API only.

### 5.3 Product form — initial stock

- Optional integer field on **creation only**; editing name/prices never touches stock.
- Input: integer ≥ 0; Arabic-Indic digits accepted (reuse or extract the digit-normalization path found in V3 — no new parsing convention).
- Empty or omitted → no movement row; on-hand defaults to 0.
- Non-empty → one `initial` movement, attributed to the active profile.

### 5.4 Product list — on-hand display

- Existing list stream joined with `watchAllOnHand`; each row shows the current on-hand (Arabic-Indic numerals, consistent with money display conventions).
- Negative values: distinct visual state + correct Arabic negative formatting; **no clamping, no warning dialog** — the signal treatment belongs to Plan 14.
- Soft-deactivated products: history preserved; list behavior unchanged from today.

### 5.5 Multi-platform distinction

- **Cross-platform rule:** all new code is pure Dart + drift. No platform channels, no plugins, no Android APIs. Table/domain patterns are portable by construction.
- **Android pilot requirement:** runtime verification happens on the Android emulator/device, Arabic locale, RTL.
- **Future platforms:** nothing in this plan constrains iOS/desktop/web.

## 6. Implementation Steps (ordered)

1. **Phase 0 report** → record in PR + dated `DECISIONS.md` entry; apply stop conditions.
2. Record decisions D1–D5 in `DECISIONS.md`.
3. Drift table + v7 migration in `app_database.dart`; run codegen (`build_runner`) — if skipped, the analyzer fails loudly; don't ship generated-file drift.
4. Migration **fixture rehearsal** (§8) — must pass before any feature code.
5. Domain entities + repository interface + pure reducer + unit tests (red-first where practical).
6. Data implementation + grouped aggregate stream; repository tests incl. per-pharmacy isolation.
7. Product form initial-stock field + widget tests.
8. Product list on-hand display + widget tests (incl. negative state, RTL).
9. **Emulator runtime migration pass** (§8).
10. Closure: `FEATURES.md` shipped entry (test counts + runtime evidence), `PROJECT_MEMORY.md`, `DECISIONS.md` rehearsal records; full suite + analyzer + CI green.

## 7. Testing Strategy

| Layer | Tests |
|---|---|
| **Unit — reducer** | empty → 0; initial only; mixed in/out; **negative result passes through unclamped**; order-independence of SUM |
| **Unit — repository** | append-only (no update/delete path exists); per-pharmacy isolation (pharmacy A never sees B's movements); profile attribution recorded; `initial` only on creation |
| **Widget — form** | field optional; rejects negative/invalid input; Arabic-Indic digits parse; creation posts exactly one `initial` movement; omitting posts none |
| **Widget — list** | on-hand renders per row; negative state renders gracefully in RTL; deactivated-product behavior unchanged |
| **Migration** | v6→v7 fixture rehearsal + emulator runtime pass (§8) |
| **Negative check** | grep-level proof nothing in `core/data/sync/` references stock movements |

Use the existing `unmountAndFlushDriftTimers` helper (Plan 07 lesson) for any test navigating away from drift-watching screens.

## 8. Migration Rehearsal (standing rule — Plan 11-H standard, non-negotiable)

1. **Fixture rehearsal:** build a v6 fixture DB containing all five ledger entry types, expense categories, mixed synced/unsynced rows, quarantine rows, products/suppliers/customers/profiles → migrate to v7 → assert `schemaVersion == 7`, `stock_movements` exists and is empty, and **every pre-existing row intact** (type/category/value counts).
2. **Emulator runtime pass:** current release APK (v6, real on-device data from Plan 11-H acceptance) → install Plan 12 build **preserving app data** → migration runs, prior data intact, existing sync behavior unaffected (one push observed), then a product created with initial stock displays correctly.
3. Both recorded in `DECISIONS.md` with observed counts — this is the second execution of the rehearsal standard; keep the template consistent.

## 9. Edge Cases

- Initial stock empty/zero → no movement row; on-hand 0.
- Negative on-hand → displayed, never clamped, never blocks anything (D3).
- Product soft-deactivated after movements → history retained; aggregation still correct.
- Two profiles on one device → movements attributed to whoever recorded them; no cross-profile visibility logic added.
- Large product counts → grouped aggregate query (5.2) prevents N+1; verify with the list test data.

## 10. Security & Performance

- Local-only; SQLCipher already encrypts the DB. No network surface, no new credentials, no telemetry.
- Notes are free-text local-only — acceptable.
- One grouped aggregate stream for the list; threshold evaluation is not introduced (Plan 14's concern).

## 11. Builder AI Instructions

**DO:** run Phase 0 fully before editing; keep the reducer pure and the repository id-based; route all cross-feature access through barrels; keep every quantity path integer; rehearse the migration before feature code lands on the emulator.

**DON'T:** touch anything under `supabase/` or `core/data/sync/`; add remote tables or wire formats; clamp negative stock; block or reorder the sales flow; introduce fractional quantities; merge movements into the activity feed (Plan 13); add low-stock thresholds or signals (Plan 14); edit migrations `0001`/`0002` or v1–v6 drift steps in place.

**Common mistakes:** per-product on-hand queries (N+1); mutable stock column "for speed"; forgetting codegen; parsing Arabic-Indic digits with a new convention instead of the shared path; posting an `initial` movement on product *edit*; letting a widget compute on-hand instead of consuming the stream.

## 12. Definition of Done

- All acceptance criteria evidenced in the PR; both rehearsal records in `DECISIONS.md`.
- On-hand displays correctly (positive, zero, negative) on the emulator in Arabic/RTL.
- Full suite green (baseline + new tests), analyzer clean, CI green incl. release APK build.
- Zero changes under `supabase/`; sync behavior demonstrated unchanged.
- `FEATURES.md` shipped entry with test counts and runtime evidence; D1–D5 recorded.

---

Builder AI may begin with Phase 0. Bring back the verification report before touching schema files.