# PRODUCT_HANDOFF_TO_STAFF_ENGINEER.md
## Pharmacy Profit Control Platform / "Smart Pharmacy Operating System"
### Product Manager AI → Staff Engineer AI
### Revision 3 — Engineering sizing confirmed; Plan 12 green-lit

**Repo reviewed:** `github.com/islamzohairy/pharmacy_saas` (main, 38 commits, through Plan 11-H, 2026-08-05)
**Method:** Repository-first. Every claim below was checked against `FEATURES.md`, `PROJECT_MEMORY.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `SECURITY.md`, `COMPLIANCE.md`, `RELEASES.md`, `REVIEW_PACKAGE.md`, `PLANS/01–11`, and `product/` (the original spec, the prior reconciliation memo, and the new 41-decision document).

**What changed in this revision:** Revision 2 handed the Staff Engineer a bounded §4.2 scope and asked for sizing plus three specific calls (stock model, sync scope, notifications timing). The Staff Engineer returned a memo with recommendations and a concrete estimate; the product owner has now confirmed all three. **Plan 12 (Inventory Foundation) is green-lit.** This revision records the confirmed decisions, the engineering sizing, and closes out Revision 2's open questions — no further product-side blockers remain before the Staff Engineer proceeds to detailed planning.

---

## 1. Executive Summary

**What exists today:** a fully built, tested, and internally-verified Android MVP covering the four Tier-1-confirmed problems — local-first identity, append-only financial ledger, product catalog + sales entry, categorized expenses, supplier/customer debt tracking, profit dashboard, one-way encrypted cloud backup, local crash visibility, activity history, compliance-prep fields. 179 tests pass, CI is green, backend verified live.

**What the product owner decided (Revision 2):** the pilot release ships the complete essential Freemium MVP — including the Basic Inventory pillar (Decision 20/26–28) — not just the Tier-1-evidence-backed slice. Signed pilot release remains the final gate.

**What's now confirmed (this revision):**
1. **Stock model:** append-only stock-movement ledger — the same audit-safe pattern the financial ledger already uses, not a mutable counter. Chosen specifically because it's consistent with the one architectural invariant this project has already paid to get right (never mutate a running total under a shared-device shift-handoff pattern; append and aggregate).
2. **Sync scope:** inventory stays **local-only**, consistent with how products/suppliers/customers already work (`DECISIONS.md`, 2026-08-02 — sync scope is ledger-only in P0). No new sync-layer scope.
3. **Notifications:** all three triggers (low-stock, large customer debt, supplier payment) **deferred until post-pilot**. The deciding factor wasn't the source-document ambiguity flagged in Revision 2 — it was a technical one the Staff Engineer surfaced: there's no reliable background-delivery mechanism yet (Android Doze/OEM battery management can silently drop a scheduled notification), and a notification that silently fails to fire would be worse for pilot-week trust than no notification at all. The underlying information (debt totals, low-stock signal) stays visible in-app; only proactive push is deferred.

**Timeline impact, stated plainly:** the inventory foundation is sized at **2–3 plan cycles** (Plans 12–14) plus one schema-migration rehearsal, added *before* the pilot start date. This is the real cost of Revision 2's scope decision, now quantified rather than estimated qualitatively.

---

## 2. Product Reality Assessment — Original Vision vs. Current Implementation vs. New Decisions

Unchanged from Revision 2 — carried forward for reference, not re-litigated:

| Artifact | What it says the MVP is |
|---|---|
| **A. Original spec** (Rev. 3) | 7 P0 items, all Tier-1-evidence-traced. Inventory is explicitly Tier 2/3, not P0. |
| **B. What's actually built** | Matches (A). No stock-quantity field exists pre-Plan-12. |
| **C. The 41-decision document** | Basic Inventory (D20/26–28) is a named MVP pillar. |

**Resolution:** (C)'s inventory pillar is in scope for the pre-pilot release by product-owner decision, now with a confirmed technical approach (§1). This remains a deliberate scope call, not new customer evidence — the pilot is still the first real signal on whether she engages with it.

The full 41-decision reconciliation table from Revision 2 is unchanged and not reproduced here in full; the only line item that moves is D26–D28, now **✅ scoped, sized, and confirmed** rather than pending.

---

## 3. User Discovery Findings

Unchanged — still n=1 real interview, same four Tier-1-confirmed problems, same open Tier 2/3 gaps (expiry, inventory pain, trust/control). Building the inventory foundation does not close this evidence gap; the pilot will still be the first real test of whether she uses or ignores it. Worth restating given this revision confirms real engineering investment ahead of that signal.

---

## 4. Freemium MVP Scope — What Ships Before the Pilot Release

### 4.1 Already implemented Freemium features
Unchanged from Revision 2 — identity/onboarding, sales, expenses, supplier/customer debt, profit calculation, dashboard, activity history, compliance-prep fields, one-way ledger backup, security posture, Arabic-first/offline-first foundation. No changes this revision.

### 4.2 Essential Freemium features still missing — build before the pilot release (confirmed technical approach)

1. **Stock-on-hand tracking, via an append-only stock-movement ledger** — not a mutable counter. Movements (stock-in, stock-out, adjustment) are recorded as immutable entries; on-hand quantity is always computed live by aggregation, mirroring the financial ledger's core invariant. **Local-only** — no cloud sync, consistent with products/suppliers/customers.
2. **Hybrid auto/manual deduction.** Sales emit a stock-out movement automatically by default; a pharmacy-level setting allows disabling automatic deduction for manual control (D27/D28).
3. **Manual stock adjustment.** Restocking and corrections post as offsetting movements against the same ledger — clean and auditable, not a fragile re-add.
4. **"Needs attention" inventory signal.** A low/zero-stock indicator surfaced in the product list and/or dashboard — in-app only, not a push notification (see §4.3).
5. **"Highest expense category" insight** on the dashboard, surfaced from data Plan 10 already captures.

**Confirmed engineering packaging (Staff Engineer estimate, accepted):**

| Plan | Scope | Effort |
|---|---|---|
| **Plan 12 — Inventory Foundation** | Stock-movement ledger (schema v7 migration), product-form initial stock, product-list stock display, repository + live-aggregate on-hand calculator. Requires a v7 migration rehearsal before it touches the pilot device, per the standing rehearsal rule from Plan 11-H. | High |
| **Plan 13 — Deduction & Adjustment** | Auto-deduct setting, sale-triggered stock-out, manual adjustment UI/logic | Medium |
| **Plan 14 — Signals & Insights** | Low-stock "needs attention" indicator, highest-expense-category dashboard insight (or folded into Plan 13) | Low–Medium |

**This is now the accepted scope for §4.2 — no broader inventory work (analytics, batch tracking, purchase orders, reorder suggestions) is authorized under it.**

### 4.3 Features intentionally deferred until pilot evidence (updated this revision)

- **Notifications (D16) — confirmed deferred, all three triggers.** Reasoning is now technical, not just a source-document ambiguity call: no reliable background-delivery mechanism exists yet (Doze/OEM battery management can silently drop scheduled work), and a silently-failing notification is a worse pilot-trust outcome than none. The information itself (debt totals, low-stock signal) stays visible in-app via existing/§4.2 surfaces — only proactive push is deferred. If debt/supplier-payment notifications are wanted later, the background-scheduler work is a prerequisite plan, sequenced after the pilot, not bolted onto §4.2.
- Expiry-loss alerting logic — unchanged, still evidence-gated.
- Employee-role enforcement — unchanged, explicitly out of MVP per D29.
- Multi-device sync, cloud restore, full account recovery — unchanged, explicitly a Future Consideration under D21; now additionally reinforced by the confirmed local-only inventory decision (§4.2 keeps the sync layer's scope exactly where it already was).
- Purchase-order workflow, detailed batch tracking, stock-movement analytics (as a reporting feature — distinct from the movement *ledger*, which is the correctness mechanism, not analytics), automatic reorder suggestions — unchanged.
- Additional Sprint-0 validation interviews — unchanged, product-side action, runs in parallel, no engineering dependency.

### 4.4 Future/P2 — do not build now
Unchanged from Revision 2. No changes this revision.

---

## 5. Pilot Strategy

Unchanged in shape, with one sequencing update: **release-process items (keystore generation, signing pipeline, version tag) should start in parallel with the §4.2 build**, per the Staff Engineer's recommendation, so they aren't the tail-end blocker once Plans 12–14 land. Ownership: the product owner/ops generates and securely holds the keystore; engineering wires signing into the pipeline and cuts the tag once Plan 14 closes.

Target user, pilot goals, onboarding, feedback collection: unchanged from Revision 2. One addition to the pilot's read-out: because stock movements post to the same activity-history surface as everything else (Plan 09/10), **inventory engagement is observable with zero new instrumentation** — a useful, low-cost signal on whether §4.2 was worth building ahead of evidence.

---

## 6. Feature Prioritization

### P0 — before/for the pilot (updated this revision)

| Feature | Status |
|---|---|
| Plan 12 — Inventory Foundation (append-only stock-movement ledger, local-only) | **Green-lit — Staff Engineer may proceed to detailed planning** |
| Plan 13 — Auto/manual deduction + manual adjustment | Queued, follows Plan 12 |
| Plan 14 — Low-stock signal + highest-expense-category insight | Queued, follows Plan 13 (or folded in) |
| Keystore generation + signing pipeline + version tag | Start in parallel with Plans 12–14, not after |
| Confirm crash-support logistics for the pilot | Unchanged, still open, low effort |

### P1 — after pilot validation (unchanged in composition)

Notifications (all three, now confirmed deferred with technical rationale), background-scheduler work as its prerequisite, direct Sprint-0 interview questions, employee-restriction enforcement, DAU-equivalent instrumentation, e-invoicing real integration (hard-gated behind `COMPLIANCE.md`, unaffected by any of this).

### P2 — unchanged from Revision 2
Customer profiles/refill reminders, WhatsApp order intake, multi-branch management, forecasting/AI, purchase-order workflow, detailed batch tracking, stock-movement *analytics* (as opposed to the movement ledger itself), reports beyond the dashboard.

**Explicitly out of scope regardless of evidence tier:** unchanged.

---

## 7. Product Risks

- **Evidence risk (unchanged):** still n=1. Confirming the inventory build doesn't change this.
- **Scope-expansion risk (now sized, not just flagged):** §4.2 adds 2–3 plan cycles plus a schema-migration rehearsal ahead of the pilot start date. This is the concrete cost of Revision 2's decision — worth the product owner seeing it stated once as a number, not just a caveat.
- **Migration risk (new, from the Staff Engineer's memo):** the v7 schema migration must be rehearsed before it reaches the pilot device, per the standing rule established after the Plan 11-H incident. Lower-stakes than a post-pilot migration would be (no real user data exists yet), but the rehearsal discipline still applies and shouldn't be skipped on that basis.
- **Inventory-adoption risk (unchanged from Revision 2):** she may not engage with stock entry/tracking at all. Now mitigated somewhat — engagement is observable for free via the existing activity-history surface (§5) — but the underlying risk that this investment doesn't pay off in the pilot is real and was made with eyes open.
- **Release-readiness risk (updated):** now explicitly de-risked by running keystore/signing/tagging in parallel with the build, rather than after — Staff Engineer's recommendation, adopted.
- **Single point of support, regulatory risk, operational risk:** unchanged from Revision 2.

---

## 8. Questions For Staff Engineer

**None blocking.** All three Revision 2 open questions are resolved:
- Stock model → append-only ledger, confirmed.
- Sync scope → local-only, confirmed.
- Notifications → deferred, all three, confirmed.

**Status: Plan 12 (Inventory Foundation) is green-lit.** Proceed to the detailed Builder-AI plan for the foundation increment. One item left at the Staff Engineer's own discretion, not a product-owner blocker: the negative-stock edge case (selling before a restock is logged) — the memo already proposed allowing negative stock with a graceful display, which is a reasonable default to resolve in-plan rather than escalate.

---

*Prepared against repo commit state through Plan 11-H (2026-08-05). Revision 3 records confirmed engineering decisions from the Staff Engineer's sizing memo. Source docs: `product/pharmacy_saas_product_specification-2.md` (Rev. 3), `product/PRODUCT_DIRECTION_FINAL.md`, `FEATURES.md`, `PROJECT_MEMORY.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `SECURITY.md`, `COMPLIANCE.md`, `RELEASES.md`, `REVIEW_PACKAGE.md`, the 41-decision document, and the Staff Engineer's Revision 2 response memo.*

---

# Revision 4 — Horizontal positioning & brand (NoNota)

**Date:** 2026-08-15. **Decision:** the product is a horizontal small-retail
product — بديل الدفتر لصاحب المحل الصغير — branded **NoNota (نونوتا)**.
Pharmacies are the FIRST PILOT VERTICAL (the confirmed persona and
go-to-market wedge), not the product definition.

**What it supersedes:** both prior names — "Pharmacy Profit Control
Platform" and "Smart Pharmacy Operating System". Locked brand record,
verbatim, in `product/BRAND_AND_ASO.md` (the future Play-listing source;
ASO strings live only there, never in the app UI).

**Scope unchanged:** no features added or removed. The rebrand touched
in-app display names, user-facing copy (4 Arabic strings), and
authoritative docs only — zero schema, zero sync, zero feature logic.
Internal schema/Dart naming (`pharmacies`/`pharmacy_id`/`Pharmacy`) is
retained as a legacy label for the generic tenant concept and must not be
renamed opportunistically (DECISIONS.md 2026-08-15).

**Honesty rule:** brand is broad, evidence story stays "proven with
pharmacies first" (n=1; pilot still ahead) — do not over-claim breadth.
