# Engineering Review — Pharmacy Profit Control Platform (Egypt)

Reviewing: `pharmacy_saas_product_specification-2.md` (Revision 3).

**Overall verdict:** the spec is unusually rigorous for a pre-development
document — the three-tier evidence model (Confirmed / Plausible / Needs
investigation) is exactly the kind of discipline that prevents a team from
building six months of the wrong feature. It should be treated as a asset,
not overhead: the implementation plans in this package inherit its tiering
language directly. But the same rigor the spec applies to *product* claims
is not yet applied to several *technical* claims baked into it. That
inconsistency is where most of the findings below come from — the spec
asks "how do we know this?" about the expiry hook but not about the offline
requirement, the auth model, or the money-storage approach. Those deserve
the same scrutiny.

None of the findings below block Sprint 0. Two (F1, F5) are cheap to fix
before any code is written and expensive to fix after. The rest are
sequencing and clarity issues, not blockers.

---

## F1 — Offline-first is asserted, not evidence-tiered

**Problem:** Section 21 states "offline requirement flagged as a scope
risk," and the spec's own MVP framing assumes a mobile-first, presumably
offline-tolerant app. But nowhere in the Evidence Log (Section 22) was the
real interview subject asked about connectivity reliability, data-loss
tolerance, or what happens if her phone breaks. This is a Tier 3 gap by the
spec's own definition — it just wasn't labeled as one.

**Why it matters:** offline-first is not a free architectural default. It
means local storage as the source of truth, a sync/reconciliation layer,
and — the part that's easy to skip — a backup story so a lost or broken
phone doesn't erase months of the exact financial history this product
exists to protect. Getting this wrong in either direction is expensive:
over-build sync infrastructure for a segment that has decent connectivity
and you've burned Sprint 0-2 on infrastructure instead of the four
confirmed problems; under-build backup for a segment that's phone-only with
no cloud habit and a lost device becomes a trust-destroying incident for
your first pilot customer.

**Risk:** high — this decision shapes the data layer, and reversing it
after Sprint 2 means touching every repository.

**Recommended improvement:** add one direct question to the Sprint 0
interview script (Section 16 already mandates expiry/inventory/trust
questions — add connectivity and "what would you do if you lost your
phone today" to the same pass, since it's free once the interviews are
already happening). Engineering proceeds now with a specific, reasoned
default rather than an unstated one — see `ENGINEERING_STRATEGY.md` §Offline
— and revisits it with Sprint 0 data alongside the Tier 2/3 product
questions.

**Impact on MVP:** none to timeline if folded into the existing Sprint 0
interview pass. High impact if skipped and discovered wrong in Sprint 3.

---

## F2 — The "flexible access model" conflates a data-model decision with an infrastructure decision

**Problem:** P0 feature #1 is "flexible pharmacy/user access model." The
product reasoning (Section 9, 21) for keeping this flexible is sound —
trust/control is Tier 2/3, not disproven, so the *role field* should exist
now. But the spec doesn't distinguish that from full **authentication
infrastructure** (accounts, login, password/OTP reset, server-side session
management), which is a materially larger and more expensive thing to
build than a role column on a user table.

**Why it matters:** the confirmed segment (Section 6, ICP-A) is n=1, works
alone, shares the phone with her father, has no employees. There is
currently zero Tier 1 evidence that she needs to *log in* at all versus
opening an app that's already scoped to her pharmacy. Building server-side
auth for a segment confirmed to be single-device, single-owner is the
mirror image of the mistake Revision 2 made with expiry: assuming a need
ahead of evidence, just on the engineering side instead of the product
side.

**Risk:** medium — wasted Sprint 0-1 effort on auth infrastructure (backend
accounts, token handling, SECURITY_STANDARDS.md's full authentication
checklist) that a single-owner pilot doesn't yet need, delaying the actual
four-confirmed-problems value moment the MVP goal (Section 10) exists to
prove.

**Recommended improvement:** apply the same hedge pattern the spec already
uses for the expiry field (Section 10: capture the field now, build the
feature when confirmed). Ship a `role` column on the local user/profile
table now (owner / family / employee-restricted) so no schema change is
needed later — but for P0, resolve identity locally (a lightweight
device-level profile switcher with an optional PIN) instead of a full
backend authentication system. Promote to real server-side auth once a
Sprint 0/ICP-B interview confirms multi-device or true employee access is
needed. This is detailed in `02_IDENTITY_AND_ACCESS_PLAN.md`.

**Impact on MVP:** reduces Sprint 0-1 scope; removes a backend dependency
from the critical path to the first pilot.

---

## F3 — No stated money-representation or ledger-integrity model

**Problem:** the spec describes financial *features* (draws, supplier debt,
customer debt, unified profit dashboard) but never states how money is
represented or how the dashboard number is derived — live aggregation over
transactions, or a maintained running balance.

**Why it matters:** this is the single highest-risk technical gap in the
document, because the entire product thesis is "know where your money
goes." Two concrete failure modes if left unspecified: (1) storing money as
floating-point produces silent rounding drift over thousands of entries;
(2) a mutable running-balance field updated by "add draw, subtract from
balance" logic is not safe against a shift-handoff race (she and her father
share the same device across shifts per Section 6/15) or a crash mid-write,
and produces a number nobody can audit or explain when it's wrong — which
directly undermines the "where does my money go" value proposition the
moment it happens.

**Risk:** high — a wrong balance in a financial tool is not a bug, it's the
product failing at its one job, and it will surface during the pilot when
it matters most for trust.

**Recommended improvement:** model money as an append-only ledger of
immutable transaction entries (typed: sale, draw, supplier-debt,
customer-debt, repayment), each storing amount in integer minor units
(piastres, not EGP floats), with the dashboard computed by aggregation over
the ledger rather than a mutated balance. Detailed in
`04_FINANCIAL_LEDGER_PLAN.md`.

**Impact on MVP:** no scope change — same P0 features, different (safer)
data model underneath. This is materially cheaper to build correctly now
than to retrofit after real transaction history exists.

---

## F4 — Localization (Arabic, RTL) is absent from the spec

**Problem:** the product targets independent Egyptian pharmacy owners, and
the confirmed persona is a real Egyptian pharmacy owner — but the spec
contains no mention of language, script direction, or currency/number
formatting conventions anywhere in Sections 1–21.

**Why it matters:** this isn't a cosmetic detail deferrable to "polish
later." Right-to-left layout affects navigation direction, icon mirroring,
form-field alignment, and text-input behavior throughout the app — it's a
foundational UI decision, not a coat of paint, and is far cheaper to build
in from the first screen than retrofit after 7+ P0 screens exist.

**Risk:** medium-high — silent assumption of English/LTR by a Builder AI
with no instruction otherwise is the likely default outcome if this isn't
made explicit, and the pilot customer may simply be unable to comfortably
use an English-only tool.

**Recommended improvement:** confirm language requirement in the same
Sprint 0 interview pass (cheap addition) — but default to Arabic-primary,
RTL-first UI now given the confirmed persona, with English as a possible
secondary/toggle rather than the reverse. Added as an explicit P0
requirement in `01_PROJECT_FOUNDATION_PLAN.md`.

**Impact on MVP:** should be treated as P0, not a fast-follow — retrofitting
RTL after screens are built LTR-first typically means rebuilding layout
logic across the app, not adding a flag.

---

## F5 — No backup story for the only copy of the customer's financial history

**Problem:** whatever the offline-first resolution (F1), the spec doesn't
address what happens to a pharmacy's transaction history if the device is
lost, stolen, factory-reset, or simply breaks — a realistic scenario over a
multi-month pilot on a single smartphone.

**Why it matters:** identical framing to F3 — this product's entire value
proposition rests on being a trustworthy record of the owner's money. A
data-loss event during the pilot doesn't just lose data, it disproves the
product's core promise to the first real customer this team has.

**Risk:** high, low-probability-but-catastrophic — exactly the kind of risk
that's cheap to design for now and devastating to discover in production.

**Recommended improvement:** even a lightweight, low-cost encrypted backup
(e.g., periodic sync of the local ledger to a managed backend) should be
P0, not deferred to the multi-device/sync work the ICP-B segment might
eventually need. This does not require building real-time multi-device
sync — just a one-way, best-effort backup path. Detailed in
`03_DATA_AND_SYNC_PLAN.md`.

**Impact on MVP:** small, well-bounded addition (a backend write path and a
background job) — much smaller than the "offline-first sync engine" scope
the spec's Section 21 risk note seems to imply is the only alternative.

---

## F6 — E-invoicing/ETA compliance is scoped as a feature, not a legal-risk spike

**Problem:** Section 11 marks e-invoice/e-receipt compliance "P1, urgent
scoping," and Section 22 correctly flags that the regulatory sourcing needs
verification against official ETA guidance before being treated as final.
Good instinct — but the spec still lists it in the same feature-priority
table as ordinary product features, which invites it to be picked up by
`api-integration`-style "read the docs, build the integration" workflow.
Government compliance interpretation is not the same task as integrating a
third-party API.

**Why it matters:** building against a misunderstood regulatory requirement
creates legal exposure for the business, not just rework for engineering.
The revenue threshold (EGP 250,000) and format requirements need
confirmation from qualified counsel or the ETA directly, not from a
compliance guide summarized by an AI agent.

**Risk:** medium (unlikely to matter before the pilot pharmacy crosses the
threshold) but high-severity if mishandled.

**Recommended improvement:** treat this as a standing open item tracked in
a project-specific `COMPLIANCE.md` (see `AI_ENGINEERING_OS_REVIEW.md`),
gated on a human/legal confirmation step before any implementation plan for
it is written — not scheduled as a normal P1 backlog item on the current
Sprint 1-4 cadence.

**Impact on MVP:** none — this only matters once threshold/scale
considerations are closer, which the confirmed pilot customer is far from
today.

---

## Minor notes (no dedicated implementation risk, worth a line each)

- **Tenant boundary:** even though multi-branch (V4) is explicitly future
  scope, the local and remote schemas should carry a `pharmacy_id` from the
  first migration — retrofitting a tenant key into an already-populated
  single-tenant schema is a much larger job than including it now for free.
- **Analytics/metrics tooling** (Section 18) isn't named — needs a decision
  (e.g., a privacy-respecting analytics SDK) before the activation/retention
  metrics in that section can actually be measured.
- **Payments/billing** isn't in this revision's scope, but when pricing
  lands, route it through a PCI-compliant Egyptian processor (e.g., Paymob,
  Fawry) rather than handling card data directly — flag this now so it
  isn't improvised later.
