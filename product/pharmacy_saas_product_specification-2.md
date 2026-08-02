# Product Management Specification
## Pharmacy Profit Control Platform — Egypt
### Revision 3 — Evidence Framing Corrected

**Document type:** Execution-ready Product Management Specification
**Prepared for:** Staff Engineer AI (technical feasibility, architecture, implementation planning)
**Source input:** Original discovery document (Parts 1–9, simulated research) + first real pharmacy owner interview
**Status:** Pre-development, pilot planning.

**What changed in this revision, in one paragraph:** Revision 2 correctly elevated the four problems the real interview confirmed, but it went too far in the other direction — it treated problems the interview simply *didn't ask about* (expiry, inventory visibility, trust/control if she ever works with others) as if they'd been disproven. That's not what happened. The interview didn't cover those areas; it didn't rule them out. This revision fixes that reasoning error everywhere it appeared and adopts a standing three-tier evidence model, used consistently from here on:

1. **Confirmed** — stated directly by a real customer in an interview. Highest confidence.
2. **Plausible / unvalidated** — surfaced by the original simulated research (or by pattern-matching to the confirmed pharmacy's situation). Still a legitimate hypothesis. Not evidence of a real problem, but not evidence *against* one either.
3. **Needs investigation** — specifically, a gap: something the interview script didn't ask, so we have no signal either way yet.

Nothing in Tier 2 or Tier 3 should be described as "not a problem," "doesn't exist," or "doesn't apply" anywhere in this document. Where earlier language did that, it has been corrected below.

---

## 1. Executive Summary

**Recommendation, unchanged:** Build, with the MVP sequenced around the four confirmed problems first — but *sequenced*, not *scoped down to only what's confirmed*. Sequencing is a build-order decision under real time and budget constraints; it is not a claim that everything else is unimportant.

**Confirmed by the real interview (Tier 1):**
1. She doesn't know where the money goes.
2. Supplier debt is a real, named struggle.
3. She takes cash from pharmacy income without separating it from actual profit.
4. She needs visibility into customers who owe her money.

She also has a smartphone and uses no digital tools today (paper-only), which is itself confirmed, not inferred.

**Plausible but unvalidated (Tier 2) — carried forward from the original research, not downgraded:** expired medicine losses, inventory/stock visibility, low-stock/reorder difficulty, and (if she ever works with non-family staff) trust/control concerns around cash and inventory handling. These were reasonably well-supported by the original simulated research across a broader hypothetical sample. One real interview that didn't ask about them changes nothing about whether they're real for her or for the wider segment — it only means they're currently unconfirmed for this specific customer.

**Needs investigation (Tier 3) — explicit gaps in what's been asked so far:** whether she experiences expiry loss, whether inventory/stock visibility is a pain for her, how she currently handles (or would handle) trust and access if she brought someone else on, and anything else the four-problem framing of this interview simply didn't surface. Sprint 0's interview plan (Section 16) is designed to close these gaps directly rather than leave them as permanent unknowns.

**MVP sequencing rationale, restated carefully:** Building the four confirmed problems first is justified because they are the only problems this specification currently has direct customer evidence for — not because the rest have been checked and found absent. The next round of interviews should ask about expiry, inventory, and trust/control directly (Section 16, Section 20), and the roadmap should be treated as genuinely open to reprioritizing once those answers exist.

## 2. Product Vision

*(Unchanged.)* Every independent pharmacy in Egypt can operate with the financial visibility and inventory control of a large pharmacy chain — without needing an expensive ERP system or technical expertise.

## 3. Product Mission

*(Unchanged from Revision 2.)* Give independent pharmacy owners a simple, affordable, mobile-first tool that answers: where does my money go, who owes me, who do I owe, and what did I actually earn today — while continuing to investigate whether expiry and inventory visibility (Tier 2/3) deserve equal billing once more evidence exists.

## 4. Market Opportunity

**Facts (unchanged):** ~70,000+ pharmacies in Egypt; realistic SaaS-addressable segment estimated at 10,000–20,000 "professional independent" pharmacies.

**Confirmed (Tier 1):** at least one real pharmacy in this market runs with zero digital tools of any kind.

**Correction from Revision 2:** Revision 2 suggested the fully-paper segment "may be larger than assumed" based on this one data point, and implied the original assumption (that most independent pharmacies have at least Excel or a basic desktop system) might be wrong. That's an overreach in the other direction — one data point can't establish segment prevalence either way. Both the original assumption and this interview's pattern are Tier 2/Tier 1 respectively for *this one pharmacy*; the actual mix across the addressable market remains a Tier 3 open question (Section 20).

**Regulatory risk:** unchanged from Revision 2 — sharper because this specific confirmed customer has no existing compliant receipt path. Still an open, urgent question (Section 19, Section 20).

## 5. Product Strategy

**Category and positioning:** unchanged — Pharmacy Business Management Platform.

**Positioning statement:** "Know where your money goes, who owes you, and who you owe — without complicated software." Retained as the lead message because it maps to Tier 1 evidence. Expiry/loss-prevention messaging (Tier 2) is retained as a secondary, still-plausible message to test — not dropped, not disproven.

**Strategic re-challenge, corrected:** Revision 2 framed the risk as "the MVP was built around the wrong hook." That framing implied the expiry hook had been shown wrong. The more accurate framing: the MVP is currently built around the *only confirmed* hook. Whether it's also the *best* hook, or whether expiry deserves equal or greater weight, is still open and should be tested directly (Section 16), not assumed either way.

## 6. Target Users & Personas

### ICP-A — Solo / Family-Operated Pharmacy (Tier 1 for the specific facts below)
- Confirmed: works alone most of the time, shares shifts with her father (nights/mornings split), no employees mentioned, has a smartphone, uses no pharmacy software/POS/ERP, paper-based process, informal reorder trigger (writes down what's low, calls suppliers), allows customer credit.
- Confirmed top problems: the four listed in Section 1.
- **Tier 2/3, not confirmed either way:** whether she has expiry losses, whether she struggles with inventory/stock visibility, and whether trust/control would become a concern if she ever brought on non-family help. "No employees" is a confirmed *current* fact about her situation — it does not mean access/trust design is irrelevant to her long-term, and it should not be read as ruling out ICP-A ever needing something like the ICP-B access model below.

### ICP-B — Multi-Employee Independent Pharmacy (Tier 2, entirely unvalidated by real interview)
- The original personas (Ahmed and related) remain a legitimate hypothesis for a different, larger-operation segment. Nothing about the ICP-A interview confirms or disconfirms this segment's existence or its pain ranking (expiry, employee leakage, etc.) — it simply hasn't been asked about yet in a real interview. Treat ICP-B exactly as before: plausible, needs its own validation.

**Correction on personas retained for later use (Mohamed, Mostafa, Karim):** still Tier 2 hypotheses, same as ICP-B — not disproven, just unconfirmed.

## 7. User Problems

**Tier 1 — Confirmed by real interview:**
1. Unclear where the money goes.
2. Supplier debt.
3. Personal cash draws mixed with pharmacy income.
4. Customer debt visibility.

**Tier 2 — Plausible, from the original simulated research, explicitly NOT downgraded to "unlikely" or "doesn't exist":**
- Expired medicine losses (originally ranked #1 in the simulated research).
- Inventory/stock visibility and reorder difficulty.
- Employee/staff trust and control concerns (applies to ICP-B, and potentially to ICP-A if her situation changes).
- Stock shortages, price-change tracking, and the other pain points from the original Part 2 ranking not yet touched by a real interview.

**Tier 3 — Needs investigation, specifically because the interview didn't ask:**
- Direct questions about expiry: "Do you ever have medicine that expires before you sell it? How often? Roughly how much does that cost you?"
- Direct questions about inventory visibility: "Do you ever run out of something you didn't expect to run out of? Do you ever have too much of something you can't sell?"
- Direct questions about trust/control: "If you ever hired someone to help, what would worry you about that?"

**Decision, restated:** MVP sequencing follows Tier 1 first because it's the only tier with direct evidence — not because Tier 2 is deprioritized on merit. The roadmap (Section 17) explicitly keeps Tier 2 items ready to move up as soon as Tier 3 questions get answered.

## 8. Product Principles

*(Unchanged — see Section 5.)*

## 9. Platform Strategy

**Confirmed:** smartphone-based, mobile-first fits. OS (Android/iOS) still unconfirmed — Tier 3.

**Access model, reframed:** Revision 2 correctly proposed a flexible, data-driven role model (not hard-coded owner/employee) rather than assuming ICP-A never needs restriction-style permissions. That reasoning holds and is strengthened by this correction: since trust/control is Tier 2/3 for ICP-A (not confirmed absent), a flexible access model isn't just a nice-to-have for ICP-B — it's a hedge against ICP-A needing the same thing later if she brings on help. This is now the explicit rationale (see Section 21 for the engineering ask).

## 10. MVP Definition

**MVP goal, unchanged in substance:** prove that a solo/family-operated pharmacy will start logging money and debts daily and will pay for it, using the smallest system that creates a real first value moment around the four confirmed problems.

**Sequencing (P0), restated with corrected justification — same list as Revision 2, different reasoning:**
1. Flexible pharmacy/user access model (owner, family/co-owner, employee-restricted as a configurable role, not hard-coded) — kept flexible specifically because Tier 2/3 trust questions remain open.
2. Lightweight product entry (cost/sell price; expiry field present and optional, not required or hidden — see below).
3. Simple sales entry.
4. Owner cash draw/withdrawal logging.
5. Supplier debt tracking.
6. Customer debt tracking.
7. Unified profit dashboard (sales, cost, profit net of draws, supplier/customer debt balances).

**Correction on expiry (important):** Revision 2 said expiry alerting was "not required to prove the core hypothesis" and demoted it to P1 because it "wasn't mentioned." The corrected reasoning: expiry alerting is sequenced to P1 because it isn't yet confirmed as urgent for the pilot segment — but the *optional expiry date field* stays in the P0 product-entry screen precisely so that if Sprint 0's next interviews confirm expiry pain (Tier 3 → Tier 1), the data is already being collected and alerting can be built without a data-model change. This is a deliberate hedge, not a dismissal.

**Still sequenced to P1, same corrected logic applies:** batch tracking, employee-restriction *enforcement* logic (the flexible role field ships in P0; the specific restricted-permission behavior for a true employee ships when ICP-B or a trust need is confirmed).

## 11. Feature Prioritization (MoSCoW / P0–P2) — Reasoning Corrected

| Feature | Priority | Evidence tier | Why this priority (corrected reasoning) |
|---|---|---|---|
| Flexible pharmacy/user access model | P0 | Tier 1 (access need) + Tier 2/3 (trust need, kept open) | Ships now because setup requires it; kept flexible specifically because trust/control is unconfirmed, not irrelevant |
| Lightweight product entry (cost/sell price + optional expiry field) | P0 | Tier 1 (needed for profit calc) | Expiry field included at zero extra onboarding cost as a hedge for Tier 2/3 |
| Simple sales entry | P0 | Tier 1 | Required to generate real numbers |
| Owner cash draw/withdrawal tracking | P0 | Tier 1 — confirmed | Directly named problem #3 |
| Supplier debt tracking | P0 | Tier 1 — confirmed | Directly named problem #2 |
| Customer debt tracking | P0 | Tier 1 — confirmed | Directly named problem #4 |
| Unified profit dashboard | P0 | Tier 1 — confirmed | Directly answers "where does my money go" |
| Expiry alerting/intelligence | P1 | Tier 2/3 — plausible, unconfirmed, **not disproven** | Sequenced after Tier 1 items because no direct evidence yet exists either way; data field ships in P0 as a hedge; alerting logic ships once Sprint 0 asks about it directly |
| Detailed batch tracking | P1 | Tier 2/3 | Same reasoning as expiry alerting |
| Employee-restriction *enforcement* (beyond the flexible role field) | P1 | Tier 2/3 for ICP-A, Tier 2 for ICP-B | Not confirmed needed by this specific pharmacy today, but explicitly not ruled out for her future or for ICP-B; the role field ships now so the enforcement logic is a fast follow, not a rebuild |
| Shift/handoff summary | P1 | Tier 1 — confirmed shift-sharing pattern, feature itself untested | Directly implied by confirmed shift-sharing, cheap extension of the dashboard |
| Purchase-order workflow | P1 | Tier 2 | Unchanged, still plausible |
| Expense tracking | P1 | Tier 2, related to Tier 1 draw-tracking | Unchanged |
| E-invoice/e-receipt (ETA) compliance | P1, urgent scoping | Regulatory fact (verified) + Tier 1 (no existing compliance path) | Unchanged from Revision 2 |
| Reports beyond dashboard | P1 | Tier 2 | Unchanged |
| Customer profiles / refill reminders | P2 | Tier 2 | Unchanged |
| WhatsApp order intake | P2 | Tier 2 | Unchanged |
| Multi-branch management | P2 | Tier 2 (different ICP) | Unchanged |
| Forecasting / AI recommendations | P2 | Tier 2/3 | Unchanged |
| Full accounting, customer app, delivery, insurance, AI diagnosis | Rejected | — | Unchanged — explicitly out of scope regardless of tier |

## 12. Product Backlog

*(Unchanged in structure from Revision 2 — Epics A through F remain as previously defined: Onboarding & Accounts, Products & Sales, Financial Control, Continuity & Handoff, Inventory & Expiry, Access Control. See Revision 2 for the full epic/feature breakdown; no structural changes needed here, only the reasoning in Sections 10–11 above.)*

## 13. User Stories

*(Unchanged from Revision 2 — the C1–C4, D1, B1/B2, and F1 stories still hold. One addition:)*

**New — Tier 3 investigation, not a build story:** As the product team, we want to ask the next 8–10 interview subjects direct questions about expiry, inventory visibility, and trust/control, so that Tier 2/3 items in this specification can be promoted to Tier 1 (confirmed) or given a real "not currently a priority for this segment" status backed by evidence — rather than staying assumed in either direction indefinitely.

## 14. Acceptance Criteria

*(Unchanged from Revision 2 for C1–C4, D1, B1 — see that revision for full Given/When/Then detail. No corrections needed here; the acceptance criteria were about system behavior, not evidence framing.)*

## 15. User Workflows

*(Unchanged from Revision 2, with one wording correction:)* the restocking workflow note in Revision 2 said the informal paper-based reorder trigger "has not yet been digitized in MVP" — that stands. The earlier framing did not claim inventory visibility was unimportant to her, and that remains correct: it's sequenced to P1 pending Tier 3 investigation, not deprioritized on the belief that it doesn't matter.

## 16. Scrum Delivery Plan

**Sprint 0 — Foundation & Continued Validation (strengthened)**
- Objective: technical foundation, plus 8–10 more real interviews.
- **Explicit interview requirement, corrected from Revision 2:** every interview must directly ask about expiry, inventory/stock visibility, and trust/control — not wait for these to come up unprompted. Revision 2's interview plan mentioned this; this revision makes it a hard requirement, because the whole point of the correction in this update is that unprompted silence is not a valid signal.
- Interview split: continue weighting toward solo/family operators (to build a real sample for ICP-A, not just n=1) while also running some ICP-B interviews (employees, existing basic tools) to test that segment on its own terms.
- Also confirm: smartphone OS, revenue relative to the EGP 250,000 e-receipt threshold, and — new — how she'd feel about hiring help someday and what would worry her about it (a light, non-leading way to probe Tier 3 trust/control without assuming the answer).

**Sprint 1–4:** unchanged in structure from Revision 2 (Financial Control Core → Debt Ledgers → Handoff & Pilot Hardening → Pilot & Segment Decision Point). The only change is that Sprint 4's decision point should explicitly re-evaluate Tier 2/3 items (expiry, inventory, trust/control) using the Sprint 0 interview answers, not just pilot usage data.

## 17. Release Roadmap

*(Unchanged from Revision 2 in shape — V1 financial core, V2 expiry/batch/employee-restriction/e-invoicing, V3 CRM-lite, V4 multi-branch, V5 forecasting.)* **Correction:** V2's expiry and employee-restriction items are described in Revision 2 as shipping "if validated." That stands, but should not be read as "unless disproven" — if Sprint 0's direct questions come back inconclusive rather than clearly negative, that's still grounds for a small, cheap validation step (e.g., a lightweight expiry-count feature) rather than indefinite deferral.

## 18. Metrics & Success Criteria

*(Unchanged from Revision 2 for activation/engagement/retention/business metrics.)* **Addition:** track, per Sprint 0 interview, whether expiry/inventory/trust questions were asked and what the answer was — this isn't a product metric, it's a research-completeness check, so this specification can honestly say which Tier 2 items have been investigated versus still open at any point in time.

## 19. Risks & Assumptions

**New, primary risk this revision addresses:** treating an unasked question as a negative answer. This was an actual error in Revision 2 (demoting expiry and dismissing employee-trust concerns based on one interview's silence on those topics) and is called out here so it isn't repeated in future revisions as more evidence arrives.

**Consequently, a live risk going forward:** if Sprint 1–2 ship without any expiry or inventory-visibility feature, and it later turns out (via Sprint 0's direct questions) that this pharmacy or others in the segment do struggle with expiry, the MVP will have under-invested in a real problem. The mitigation is already in place (optional expiry field captured in P0, Section 10) but the alerting logic itself is not built until confirmed — worth the Staff Engineer's awareness that this could become a fast-follow request, not a distant V2 item.

**Carried forward, unchanged:** sample-size risk (still n=1 for Tier 1 evidence), regulatory risk (unchanged), bookkeeping-discipline risk (unchanged), access-model risk (unchanged, now with the corrected rationale in Section 9), distributor-partnership channel risk, offline-first technical-complexity risk, and the standing pricing assumption.

**Retired in Revision 2, reinstated here as "Tier 2/3, not retired":** "employee resistance to surveillance" was marked retired in Revision 2 on the grounds that this specific pharmacy has no employees. Corrected: this risk is dormant for the *currently confirmed* facts about this one pharmacy, but it is not retired from the specification, because trust/control remains a live Tier 2/3 question for both her possible future and for ICP-B.

## 20. Open Questions

Unchanged list from Revision 2 (Section 20), all still open — with one framing correction: these should be read as genuine unknowns in both directions, not as questions where "no" is the expected or default answer. In particular:

1. Revenue vs. the EGP 250,000 e-receipt threshold — still open.
2. Does she experience expiry loss when asked directly — still open, **not "probably not."**
3. Is the fully-paper pattern common across the segment — still open.
4. What does "separating profit from draws" look like in her own words — still open.
5. How does access/trust actually work between her and her father, and what would she want if she ever brought on outside help — still open, **not "probably not relevant since she has no employees."**
6. Device/OS mix — still open.
7. Does the ICP-B segment (employees, existing tools) hold up under real interviews — still open.

## 21. Staff Engineer Handoff

*(Unchanged from Revision 2 in technical substance — flexible role-as-data access model, first-class money-movement transaction types for draws/supplier debt/customer debt, lightweight product entry with an optional expiry field, offline requirement flagged as a scope risk, standard security posture.)* **One reinforced point:** the optional expiry field in the P0 product-entry screen is not a placeholder for "later, if ever" — it exists specifically so that Sprint 0's direct expiry questions can convert straight into a shippable alerting feature without a schema change if the answer turns out to be "yes, this matters." Build it with that path in mind.

## 22. Appendix

### Evidence Log

**Interview #1 (real, Tier 1 for what was asked; Tier 3 for everything not asked):**
- Subject: independent Egyptian pharmacy owner, works alone most of the time, shares shifts with her father (she: nights, father: mornings).
- Tools used today: smartphone only; no pharmacy software, POS, ERP, or digital system; paper notes only.
- Restocking process: informal — writes down what's low/finished, calls suppliers directly.
- Customer credit: allows some customers to take medicine and pay later.
- **Confirmed problems (asked and answered):** unclear money flow, supplier debt, personal cash draws mixed with pharmacy income, customer debt visibility.
- **Not asked, therefore unknown (corrected from Revision 2, which incorrectly treated these as "not mentioned = not present"):** expiry/expired-medicine loss, inventory/stock-visibility problems, trust/control concerns around potential future staff. These remain open Tier 2/3 items pending direct questions in future interviews.

**Original discovery document (Tier 2, simulated):** all nine parts retained as a legitimate hypothesis set. Where Tier 1 evidence conflicts with a Tier 2 claim, Tier 1 leads for sequencing — but Tier 2 claims that haven't been directly contradicted remain live hypotheses, not rejected ones.

**Regulatory source note (unchanged):** Egypt e-invoicing/e-receipt facts are drawn from current (2026) third-party compliance guides referencing ETA Resolution No. 281/2025 and Law No. 206/2020. Verify directly against official ETA guidance before treating as final for legal/compliance purposes — this is a product document, not legal advice.
