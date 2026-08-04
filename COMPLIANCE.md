# Compliance — Pharmacy Profit Control Platform

This file exists because `AGENT_BEHAVIOR.md`'s default ambiguity rule
("ask one question, or state an assumption and proceed") is the right
default for engineering ambiguity and the wrong default for regulatory
ambiguity. Nothing in this file should be implemented on an agent's stated
assumption — every item needs an explicit `confirmed-by-counsel` status
before `architect-agent` produces a plan for it.

Status values: `unconfirmed` / `confirmed-by-counsel` /
`implemented`.

## Items

### E-invoicing / e-receipt (ETA compliance)
**Status:** unconfirmed
**What:** Egypt e-invoicing/e-receipt requirements, referencing ETA
Resolution No. 281/2025 and Law No. 206/2020, including the EGP 250,000
revenue threshold that determines when a compliant receipt path is
legally required.
**Source:** product spec Revision 3 §22 flags this itself as "drawn from
current (2026) third-party compliance guides... verify directly against
official ETA guidance before treating as final for legal/compliance
purposes — this is a product document, not legal advice."
**Gate:** do not write an implementation plan for this item, and do not
implement anything against it, until this status is
`confirmed-by-counsel` with the actual threshold, format, and integration
requirements confirmed directly against official ETA guidance or
qualified counsel — not summarized by an AI agent from a compliance guide.
**Why it's tracked here and not in `FEATURES.md`:** `FEATURES.md` P1 list
references this item but explicitly defers to this file's gate — the
two files should never show conflicting status; this file is the
authoritative one for compliance state.

### Compliance-prep fields (local capture only)
**Status:** implemented (data capture) — not a compliance feature
**What:** PLANS/10 Phase 4 added optional `tax_registration_number` and
`legal_business_name` fields to the local `Pharmacies` table, editable
on the Settings screen. These exist for future use in the e-invoicing
item above and are deliberately inert: optional, no validation, no
network use, and no e-invoice path built against them.
**Gate:** this item does **not** change the e-invoicing item's
`unconfirmed` status above, and does **not** authorize implementing
anything against those fields for e-invoicing until that item reaches
`confirmed-by-counsel`.

## Log
<!-- append confirmation events here as they happen, newest at the bottom -->
