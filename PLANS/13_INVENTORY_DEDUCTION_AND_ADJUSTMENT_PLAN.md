# PLANS/13_INVENTORY_DEDUCTION_AND_ADJUSTMENT_PLAN.md

**Plan:** 13 — Inventory Deduction & Adjustment (Basic Inventory pillar, increment 2 of 3)
**Owner:** Staff Engineer AI · **Executor:** Builder AI (single execution cycle)
**Dependencies:** Plan 12 complete incl. tracked-vs-zero fix (`50a0492`); schema at v7
**Remote impact:** **None.** Local-only. Zero changes under `supabase/`, to the sync layer, or to any SECURITY DEFINER surface.

## 1. Objective

Make stock move. Plan 12 built the ledger and the on-hand display; Plan 13 gives it its three flows: **sales deduct stock automatically by default** (D27/D28), the owner can **turn auto-deduction off** in favor of manual control, and the owner can **manually add or correct stock** through a two-mode adjustment sheet. It also closes Decision D2 from Plan 12: stock movements merge into the activity history. Plan 14 remains responsible for the low-stock signal and the expense-category insight — not this plan.

## 2. Scope

**Included:**
- Phase 0 verification gate (read-only).
- Drift schema **v8**: `pharmacies.auto_deduct_stock` column + migration, with the standing **migration rehearsal** (fixture + emulator runtime pass).
- Pharmacy-level **auto-deduct toggle** in the existing Settings screen, default ON.
- **Sale-triggered `stock_out`** movement per sale line, applied only to tracked products.
- **Manual adjustment sheet**: Add mode (`stock_in`) and Correct mode (`adjustment`), live outcome preview, optional note.
- Product-row **action sheet** as the entry point (adjust stock / edit / deactivate).
- **Activity-feed merge** for manual stock movements (D2 closure).
- `DECISIONS.md` entries D6–D10; standard `FEATURES.md` / `PROJECT_MEMORY.md` closure.

**Excluded (do not let scope creep in):**
- Low-stock / "needs attention" signal, highest-expense-category insight → **Plan 14**.
- Per-product movement-history screen → not in §4.2's authoritative list. `getMovements` stays repository-only. If the pilot asks "why is my stock this number," that's a fast-follow candidate, not Plan 13 scope.
- Any sync/remote work, notifications, barcode, purchase orders, batch tracking.
- Any change to the financial ledger, profit calculation, or sale prices. Stock is the quantity domain only.

## 3. Confirmed Decisions (record verbatim in `DECISIONS.md`)

- **D6 — Auto-deduct applies only to tracked products.** Tracked = has ≥1 movement. Selling an untracked product never creates a movement, even with auto-deduct ON — you cannot subtract from a quantity that was never declared, and a phantom negative would contradict the tracked-vs-zero distinction Plan 12 established. Tracking activates per product with its first movement.
- **D7 — Adjustment is two modes with a live preview.** Add mode posts `stock_in` (+qty, qty ≥ 1). Correct mode posts `adjustment` with delta = target − current on-hand (target ≥ 0; absent on-hand counts as 0). **Zero-delta corrections are rejected gracefully, never posted** — no noise movements. `initial` remains creation-form-only.
- **D8 — Sale-first ordering for the sale+stock_out pair.** If a single drift transaction across the two writes is not achievable without restructuring, the sale ledger write must succeed first; a failed stock movement after a successful sale is logged via the Plan 09 error path and recoverable via manual adjustment. Money correctness outranks stock. Transaction preferred if cheap — Phase 0 decides which path applies.
- **D9 — One `stock_out` movement per sale line**, mirroring the sale. Auto-deduct **never blocks or reorders a sale**, regardless of resulting on-hand (negatives allowed per D3).
- **D10 — Activity feed shows manual movements only.** `stock_in` and `adjustment` appear in the feed attributed to the recording profile; auto `stock_out` does **not** get its own feed row — the sale row already represents the event, and doubling feed rows per sale violates the low-information-density principle. The movement ledger remains the full audit record.

## 4. Phase 0 — Verification Gate (read-only; no code changes)

| # | Check | Pass criteria |
|---|---|---|
| V1 | `schemaVersion` | == 7 (Plan 12 shipped); v8 is the next slot |
| V2 | `recordSale` wiring | Located the exact sale-write path (screen → provider → use case → repository); determined whether both writes can share one drift transaction — **this decides D8's path; record the finding** |
| V3 | Product-row tap behavior today | What tap does now, which widget tests cover it — the action-sheet change will modify this flow |
| V4 | Settings screen + `updatePharmacySettings` path | Where Plan 10's pharmacy fields live; column-addition pattern for `pharmacies` |
| V5 | Activity-feed provider | Plan 10's merge/limit structure; how a second source joins (cap stays **100 combined**) |
| V6 | Baseline test count | Measured empirically by running the suite — do not carry a number from any prior report |

**Stop conditions:** V1 ≠ 7; V2 shows the sale path touches money/quantity parsing; achieving atomicity would require cross-feature data-layer restructuring → report before proceeding.

## 5. Technical Design

### 5.1 Schema (drift v8, additive-only)

`pharmacies` gains `auto_deduct_stock INTEGER NOT NULL DEFAULT 1`. Migration is one column add. No new tables; `stock_movements` untouched.

### 5.2 Auto-deduct hook

Coordinator lives at the **sales presentation/provider layer**, importing feature **barrels only** (Plan 05 precedent: the sales screen already composes ledger + products + identity barrels; inventory barrel joins the same way). Per sale line:

```
recordSale(line)                     // always, first
if (autoDeduct && isTracked(productId)):
    recordMovement(stock_out, -qty)  // same transaction if V2 allows; else sequential + error-log on failure
```

`autoDeduct` is read from the pharmacy settings stream; `isTracked` from the on-hand provider's map-key semantics (absence = not tracked — Plan 12's contract).

### 5.3 Manual adjustment

- **Entry point:** tapping a product row opens an action sheet: **"تعديل المخزون"** (primary), **"تعديل المنتج"**, **"إيقاف"** — replacing direct tap-to-edit (pre-pilot is the right moment; no user muscle memory exists yet). Available for tracked and untracked products alike; for untracked, it is how tracking begins.
- **Sheet:** product name + current on-hand (or "—" if untracked) → segmented mode:
  - **إضافة كمية:** integer ≥ 1, Arabic-Indic digits via the shared `normalizeDigits` path; preview "بعد الإضافة: ٧٠"; optional note.
  - **تصحيح الكمية:** integer ≥ 0; preview shows delta + new total ("الفرق: −٥ · الجديد: ٤٥"); optional note; zero delta → inline "لا يوجد تغيير" state, commit disabled.
- Commit posts the movement attributed to the active profile (caller-resolved, plan-04 precedent), dismisses, list updates via the existing stream.

### 5.4 Settings toggle

SwitchListTile in the existing Settings screen: **"خصم المخزون تلقائيًا عند البيع"** + one helper line explaining the behavior. Persists through the existing `updatePharmacySettings` path extended with the new column. RTL-safe.

### 5.5 Activity feed

Feed provider merges two sources — ledger entries (existing) + stock movements filtered to `stock_in`/`adjustment` (D10) — sorted by `occurred_at` desc, capped at **100 combined**. New Arabic copy per movement kind incl. product name and signed quantity.

### 5.6 Multi-platform distinction

All new code is pure Dart + drift. No platform channels, plugins, or Android APIs. Runtime verification on the Android emulator in Arabic/RTL; nothing here constrains future platforms.

## 6. Implementation Steps (ordered)

1. Phase 0 report → PR + dated `DECISIONS.md` entry; apply stop conditions; record V2's transaction finding and the chosen D8 path. ✅ (commit 0446f66)
2. Record D6–D10 in `DECISIONS.md`. ✅ (commit 0446f66)
3. v8 migration + **fixture rehearsal before any feature code** (v7 fixture must include `stock_movements` rows of all four types, quarantine rows, full ledger variety → migrate → assert column default and every pre-existing row intact). ✅ (commit bacf355)
4. Settings column + provider + toggle UI + tests. ✅ (commit 3fe345d)
5. Auto-deduct hook + unit tests (the full matrix) + sales-flow widget tests. ✅ (commit 007f9ce)
6. Action sheet + adjustment sheet + widget tests. ✅ (commit e3978fe)
7. Activity-feed merge + tests. ✅ (commit 58e6c1e)
8. Emulator runtime migration pass (preserve app data; verify pre-existing on-hand intact; then live exercise: tracked sale deducts, untracked sale doesn't, toggle off stops deduction, manual add/correct work). ✅ (2026-08-13, emulator-5556 release build; evidence in `DECISIONS.md`)
9. Closure: `FEATURES.md` shipped entry with test counts + runtime evidence, `PROJECT_MEMORY.md`, `DECISIONS.md` rehearsal records; full suite + analyzer + CI green. ✅ (suite 257/257, analyzer clean; commits 58e6c1e + docs)

## 7. Testing Strategy

| Layer | Tests |
|---|---|
| **Unit — deduct matrix** | tracked×ON → movement; tracked×OFF → none; **untracked×ON → none (D6)**; untracked×OFF → none; multi-line cart → one movement per line (D9); negative result allowed, sale never blocked |
| **Unit — adjustment** | add posts +qty; correct posts signed delta incl. negative; zero-delta rejected; absent on-hand treated as 0 |
| **Unit — ordering (D8)** | stock-write failure after successful sale → sale stands, error logged; (if transaction path: both-or-nothing) |
| **Widget — sheets** | both modes, preview math, Arabic-Indic input, validation copy, zero-delta commit disabled; action-sheet entry incl. untracked product |
| **Widget — toggle** | persists across restart; default ON on fresh pharmacy |
| **Widget — feed** | manual movements render attributed; auto stock_out absent (D10); ordering; 100-combined cap |
| **Migration** | v7→v8 fixture rehearsal + emulator runtime pass |

`unmountAndFlushDriftTimers` for drift-watching navigation tests (Plan 07 lesson).

## 8. Edge Cases

- Sale of untracked product with auto-deduct ON → silent no-op on stock; on-hand stays "—".
- Tracked product sold below zero → on-hand negative, displayed per Plan 12's D3 treatment; sale unaffected.
- Correct-mode on untracked product → delta against 0; becomes tracked via `adjustment`.
- Stock-write failure mid-sale → D8 ordering guarantees the financial record is never lost.
- Feed with heavy sale volume → cap holds; manual movements compete fairly for the 100 slots by recency.

## 9. Security & Performance

- Local-only; SQLCipher covers new data automatically. No network surface.
- No new periodic work; deduction piggybacks on the existing sale write; feed merge reuses existing streams — no extra polling.

## 10. Builder AI Instructions

**DO:** run Phase 0 fully first; keep quantities integer; reuse `normalizeDigits`; attribute movements to the caller-resolved profile; treat V2's transaction finding as a recorded decision, not an improvisation.

**DON'T:** touch `supabase/` or `core/data/sync/`; deduct untracked products; post zero-delta movements; render auto stock_out in the feed; build a per-product history screen; clamp negatives; modify `stock_movements` rows; alter sale prices, profit math, or `LedgerEntryType.wireName`.

**Common mistakes:** putting the deduct hook inside the ledger domain (it's a sales-presentation coordination); letting a failed stock write roll back the sale; double feed rows per sale; forgetting the feed cap is combined; editing v1–v7 migration steps in place; new digit-parsing conventions.

## 11. Definition of Done

- Deduct matrix fully green incl. the D6 untracked case; adjustment previews verified on-device in Arabic/RTL.
- Both rehearsal records in `DECISIONS.md`; runtime pass shows pre-existing on-hand intact post-migration.
- Full suite green (measured baseline + new tests), analyzer clean, CI green incl. release APK build.
- Zero changes under `supabase/`; D6–D10 recorded; `FEATURES.md` shipped entry with evidence.

---

Builder AI may begin with Phase 0. Bring back the verification report — **especially the V2 transaction finding** — before touching schema files. After Plan 13 closes: Plan 14 (signals & insights), then the release gate — keystore, tag, signed pilot build.