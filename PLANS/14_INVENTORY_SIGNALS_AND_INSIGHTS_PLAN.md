# PLANS/14_INVENTORY_SIGNALS_AND_INSIGHTS_PLAN.md

**Plan:** 14 — Signals & Insights (Basic Inventory pillar, increment 3 of 3 — final §4.2 build increment)
**Owner:** Staff Engineer AI · **Executor:** Builder AI (single execution cycle)
**Base:** `main` at `a44eded` (Plans 12+13 merged); schema at v8; measured baseline 257/257 — re-measure, don't carry
**Remote impact:** **None.** Local-only. Zero changes under `supabase/`, to the sync layer, or to any SECURITY DEFINER surface.

## 1. Objective

Close §4.2 — the authoritative essential-Freemium list from the Product Manager's Revision 3 handoff. Two deliverables:

1. The **"needs attention" inventory signal**: which products are low or out of stock, surfaced in the product list (badges) and on the dashboard (attention count on the products hub tile).
2. The **highest-expense-category insight** on the dashboard, using expense-category data Plan 10 already captures.

After this plan the §4.2 build is complete. The signed pilot release then remains the final gate — nothing ships to the pilot device until the release process (keystore, `ci.yaml` restoration, version tag, release-config checklist) closes as well.

## 2. Scope

**Included:**
- Phase 0 verification gate (read-only).
- Drift schema **v9**: `products.low_stock_threshold` (nullable) + migration, with the standing **migration rehearsal** (fixture + emulator runtime pass).
- **Out-of-stock signal**: tracked products with on-hand ≤ 0 — always on, no configuration.
- **Low-stock signal**: tracked products with a threshold set and 0 < on-hand ≤ threshold.
- Optional **threshold field** on the product form — editable at any time; it is configuration, not a stock movement.
- Product-list badges + dashboard attention count.
- **Highest-expense-category insight** on the dashboard, following the range selector.
- `DECISIONS.md` entries D14–D16; standard `FEATURES.md` / `PROJECT_MEMORY.md` closure.

**Excluded (do not let scope creep in):**
- Notifications of any kind — all three triggers confirmed deferred (Revision 3 §4.3; technical rationale: no reliable background-delivery mechanism exists).
- Expiry alerting, employee-role enforcement, multi-device sync/restore, purchase orders, batch tracking, stock-movement analytics, reorder suggestions.
- Any sync/remote change. Thresholds are local, like products.
- Any change to the financial ledger, profit math, or money handling.

## 3. Confirmed Decisions (record verbatim in `DECISIONS.md`)

- **D14 — Signals apply only to tracked products.** Untracked products never signal — a product with no declared quantity cannot be "low." Out-of-stock = tracked ∧ on-hand ≤ 0 (negative included — worse than zero, never hidden). Low = tracked ∧ threshold set ∧ 0 < on-hand ≤ threshold. Threshold unset → out-of-stock signal only. Alternatives considered: global threshold (rejected — one number produces noise across heterogeneous products); out-of-stock-only MVP (rejected — under-delivers §4.2 item 4's "low **or** out of stock").
- **D15 — Threshold is a nullable product column, editable at any time.** It is configuration, not a movement — editing it posts nothing to the movement ledger. Integer ≥ 0, optional, Arabic-Indic input via the shared `normalizeDigits` path. (Note: a threshold of 0 adds nothing beyond the out-of-stock signal; helper copy should guide toward ≥ 1.)
- **D16 — The expense insight follows the dashboard range selector** (today/week/month) and hides entirely when the selected range has no expenses — no empty-state noise, per the low-information-density principle. Ties break deterministically (total, then category order).

## 4. Phase 0 — Verification Gate (read-only; no code changes)

| # | Check | Pass criteria |
|---|---|---|
| V1 | `schemaVersion` on `main` | == 8 (Plans 12+13 merged at `a44eded`); v9 is the next slot |
| V2 | Dashboard structure | Range-selector data flow for expense aggregation located (Plan 10 expense-category data path); where one insight line fits under the profit card without crowding it; products hub-tile composition located |
| V3 | Product tile post-Plan-13 | Current layout documented (stock line, badges absent, row-tap → action sheet); badge placement chosen that doesn't collide with the stock line or the tap affordance, RTL included |
| V4 | Products table pattern | Column-addition precedent confirmed (v5/v8 style `addColumn`); product form structure for adding the threshold field next to initial stock |
| V5 | Baseline test count | Measured empirically by running the suite — must reconcile with the recorded Plan 13 closeout (257); carry nothing forward |

**Stop conditions (Major Change Rule):** V1 ≠ 8; V5 doesn't reconcile with the recorded closeout; expense-category aggregation would require touching money/quantity math. Stop, report, do not fix inline.

## 5. Technical Design

### 5.1 Schema (drift v9, additive-only)

`products` gains `low_stock_threshold INTEGER NULL`. One column add. Migration rehearsed per the standing rule before it touches any device.

### 5.2 Signal derivation (pure, domain layer)

One pure function in the inventory feature domain:

```
signal(onHand: int?, threshold: int?) → none | low | outOfStock
  null on-hand (untracked)        → none            (always — D14)
  on-hand ≤ 0                     → outOfStock
  threshold set ∧ on-hand ≤ thr.  → low
  otherwise                       → none
```

Derivation lives in the domain; products presentation and the dashboard provider consume it. **No widget computes signal state.**

### 5.3 Product list

Badge on the tile per signal:
- **نفد المخزون** (out of stock) — error treatment, consistent with Plan 12's negative display.
- **مخزون منخفض** (low) — warning treatment.

Untracked rows unchanged. RTL-safe; the badge must not displace the stock line or the row tap affordance from Plan 13.

### 5.4 Dashboard

- **Attention count:** the products hub tile gains a small count — tracked products currently low or out of stock; **hidden at zero**.
- **Expense insight:** one line under the profit card — top expense category for the selected range with its amount (and share of total expenses). Recomputes on range switch. Empty range → line hidden.

### 5.5 Product form

Threshold field, optional, integer ≥ 0, shown in **both create and edit** (unlike initial stock, which is creation-only — different semantics: threshold is configuration). Helper copy guides toward ≥ 1. Changing it posts no movement.

### 5.6 Multi-platform distinction

- **Cross-platform rule:** all new code is pure Dart + drift. No platform channels, plugins, or Android APIs. Nothing in this plan constrains future platforms.
- **Android pilot requirement:** runtime verification on the Android emulator, Arabic locale, RTL.
- **Flutter Web note:** not in scope, per the Staff Engineer assessment — SQLCipher has no web build; this plan does nothing to address or prejudice that decision.

## 6. Implementation Steps (ordered)

1. **Phase 0 report** → PR description + dated `DECISIONS.md` entry; apply stop conditions.
2. Record D14–D16 in `DECISIONS.md`.
3. v9 migration + **fixture rehearsal before any feature code** (v8 fixture must include: products with and without thresholds, stock movements of all four types, quarantine rows, full ledger variety incl. expense categories → migrate → assert column exists, all pre-existing rows intact).
4. Signal derivation function + unit tests (full D14 matrix) — red-first where practical.
5. Threshold field in the form + widget tests.
6. Product-list badges + widget tests (RTL included).
7. Dashboard: attention count + expense insight + widget tests (range switching, empty-range hiding, tie-break, hidden-at-zero).
8. **Emulator runtime migration pass**: release build installed data-preserving on emulator-5556 (Plans 12+13 real data incl. Aspirin/Paracetamol must survive intact); then live exercise — sell a tracked product down to zero → out-of-stock badge appears; set a threshold above current on-hand → low badge appears; expense insight matches the selected range; attention count matches the list.
9. Closure: `FEATURES.md` shipped entry with **reconciled** test counts (baseline + new = total, matching suite output — the Plan 13 lesson) + runtime evidence; `PROJECT_MEMORY.md`; rehearsal records in `DECISIONS.md`; full suite + analyzer + release APK build green.

## 7. Testing Strategy

| Layer | Tests |
|---|---|
| **Unit — signal matrix** | untracked → none; tracked zero → outOfStock; tracked negative → outOfStock; below threshold → low; above threshold → none; threshold unset with low qty → none; on-hand == threshold boundary → low; threshold 0 adds nothing beyond outOfStock |
| **Unit — insight** | top-category selection; tie-break (total, then category order); empty range → absent |
| **Widget — form** | threshold optional; rejects invalid/negative; Arabic-Indic digits parse; edit-time change posts **no** movement; create and edit both show the field |
| **Widget — list** | both badges render correctly in RTL; untracked row shows no badge; badge coexists with stock line + tap target |
| **Widget — dashboard** | attention count renders / hidden at zero; insight follows range switch; hidden when range has no expenses |
| **Migration** | v8→v9 fixture rehearsal + emulator runtime pass |

Use `unmountAndFlushDriftTimers` for drift-watching navigation tests (Plan 07 lesson).

## 8. Edge Cases

- Threshold 0 → behaves as "out-of-stock only" (low requires on-hand > 0).
- Product soft-deactivated after threshold set → signals follow list visibility rules (deactivated products excluded from the active list; nothing new computed for them).
- Negative on-hand → outOfStock, never clamped, never hidden (D3 lineage).
- Range switch while insight visible → recompute, don't flash stale values.
- Attention count and list badges must always agree — both consume the same derivation.

## 9. Security & Performance

- Local-only; SQLCipher covers the new column automatically. No network surface, no telemetry.
- Signals derive from existing on-hand streams — no new periodic work, no polling. The attention count is one pass over the already-computed per-product signals.

## 10. Builder AI Instructions

**DO:** run Phase 0 completely before editing; keep signal derivation pure and in the inventory domain; reuse the shared `normalizeDigits` path; hide empty states rather than labeling them; reconcile test counts against measured output at closure.

**DON'T:** touch `supabase/` or `core/data/sync/`; signal on untracked products; post movements from threshold edits; add notifications, expiry logic, reorder suggestions, or movement analytics; crowd the profit card; edit v1–v8 migration steps in place; introduce new digit-parsing conventions.

**Common mistakes:** computing signal state in widgets; letting the badge fight the row's tap affordance in RTL; showing the expense insight when the range has no expenses; treating the threshold like initial stock (creation-only) or like a movement; asserting carried-forward test counts instead of measured ones.

## 11. Definition of Done

- Signal matrix fully green, including untracked and boundary cases; badges, attention count, and insight verified on-device in Arabic/RTL.
- Both rehearsal records in `DECISIONS.md`; Plans 12–13 runtime data intact post-migration.
- Full suite green with **reconciled** counts (measured baseline + new = total), analyzer clean, release APK builds.
- Zero changes under `supabase/`; D14–D16 recorded; `FEATURES.md` shipped entry with evidence.

## 12. After This Plan Closes

1. **Staff Engineer runs the Freemium MVP verification pass** — §4.1/§4.2 line items re-verified against the repo at the Plan 14 commit, the 41-decision reconciliation re-run, Arabic/RTL copy audited across all new surfaces. Verdict: *essential Freemium complete → release gate*, or *gap found → Plan 15*. Known items that will be surfaced explicitly at that pass: D37 instrumentation (deferred, manual proxy for pilot #1), device-loss recovery (deferred under D21, operational acceptance), and inventory discoverability in onboarding (watch-item for the pilot read-out).
2. **Release gate** (only after verification passes): `ci.yaml` restored with `--dart-define-from-file=.env.local` baked in, keystore wired, release-config checklist (INTERNET permission, env defines, signing, post-build backup smoke check), version tag cut, signed pilot APK.

---

Builder AI: branch from `main` (`a44eded`), begin with Phase 0, and bring back the verification report before touching schema files.