# AI Engineering OS Review — Applied to the Pharmacy SaaS Project

Reviewing: the `ai-engineering-os` workspace (`CORE_SYSTEM/`, `AGENTS/`,
`SKILLS/`, `PROJECTS/_TEMPLATE/`).

**Overall verdict:** this is a well-built system — better than most
first-pass "AI operating systems" reviewed at this stage. The design
philosophy stated in `README.md` ("every rule exists to remove a decision,
a re-read, or a silent mistake") is actually followed, not just stated: the
memory-as-files decision, the pinned-model-per-agent decision, and the
small MCP-server list are all defended with real reasoning in
`RESEARCH_FINDINGS.md` rather than asserted. The seven agents and nine
skills cover the day-to-day feature/bug/refactor/release loop for a
solo-developer Flutter portfolio well.

It was built against a portfolio of offline-first, single-user, no-backend
apps ([[savings-app]], [[fitness-app]], [[wormag-app]]). The pharmacy
platform is the first project in the portfolio that is genuinely
multi-tenant, handles another party's money, and carries real regulatory
exposure. That shift exposes four gaps — none large enough to justify a
new agent or a system rewrite, but real enough to fix before Sprint 0.

**Explicit non-recommendation:** I am *not* recommending a new agent
persona (e.g., a "backend-agent" or "compliance-agent"). The backend
surface here is thin — a managed Postgres backend (see
`ENGINEERING_STRATEGY.md`), not a hand-rolled service — and doesn't carry
enough distinct daily decision-making to earn a dedicated persona under
this system's own bar ("does this remove a decision an agent would
otherwise make inconsistently?"). Widening two existing files does the
same job at lower ongoing cost.

---

## Gap 1 — `database-design` skill and `architect-agent` don't distinguish local schema from remote/multi-tenant schema

**Current state:** `SKILLS/database-design/SKILL.md` and
`AGENTS/architect-agent.md` are written for a single, on-device schema —
appropriate for the existing portfolio. This project has two schemas that
must stay reconcilable: the local `drift`/sqlite schema and a remote
multi-tenant Postgres schema, plus row-level tenant isolation
(`pharmacy_id`) on the remote side that has no local-schema equivalent.

**Why it matters:** if this distinction isn't explicit, an agent asked to
"add a column" is equally likely to touch only the local schema, only the
remote schema, or both inconsistently — exactly the class of silent,
inconsistent decision this system's own design philosophy says a rule
should prevent.

**Recommended improvement:** add a short "Local vs. remote schema" section
to this project's own `ARCHITECTURE.md` (project-specific, not a
`CORE_SYSTEM/` change — the rest of the portfolio doesn't have this
problem) stating that any schema change must state its target (local-only,
remote-only, or both-with-migration-path) as part of the `database-design`
skill's existing step 1. No change to the skill file itself is needed; its
workflow already asks for "the migration path for existing data," which
just needs to be answered for both schemas here.

---

## Gap 2 — `SECURITY_STANDARDS.md`'s authorization section is written for single-user offline apps

**Current state:** "Roles/permissions checked server-side (**or in the
local data layer for offline single-user apps**)." That parenthetical is
correct for the rest of the portfolio and actively wrong guidance for a
multi-tenant SaaS product, where a client-side or purely-local permission
check is not authoritative for anything shared across a tenant boundary.

**Why it matters:** this file is loaded automatically into every session
across every project (`CORE_SYSTEM/`, never duplicated). Leaving the
parenthetical as-is risks an agent correctly citing the file and building
client-trusted authorization for a case it doesn't apply to.

**Recommended improvement:** this is a `CORE_SYSTEM/` change, not a
project-only one — the same ambiguity would bite any future multi-tenant
project in the portfolio. Tighten the line to make the local-data-layer
exception conditional on true single-tenant, single-device apps, and add
one line: "for any multi-tenant or backend-backed app, server-side
enforcement (e.g., Postgres RLS) is the authoritative check regardless of
what the client displays." Small, high-leverage edit — a decision this
system would otherwise let an agent make inconsistently per-project.

---

## Gap 3 — No stated principle for financial/ledger data integrity

**Current state:** `FLUTTER_STANDARDS.md` covers architecture, state
management, offline/caching, testing, and performance well, but has
nothing about representing or mutating money. `DEFINITION_OF_DONE.md` and
`testing-agent.md` both correctly flag "money movement" as a critical flow
requiring runtime verification — but verifying a wrong *design* (a mutable
balance field, floating-point currency) just confirms the wrong thing
works.

**Why it matters:** this is exactly the kind of one-time decision the
system's philosophy says belongs in `CORE_SYSTEM/` rather than re-decided
per project — and it's reusable well beyond this app, since any future app
in this portfolio that touches money inherits the same risk class.

**Recommended improvement:** add a short "Financial data" subsection to
`CORE_SYSTEM/FLUTTER_STANDARDS.md`: money stored as integer minor units,
never floats; balances derived by aggregation over an append-only,
immutable transaction ledger rather than mutated in place; any correction
is a new offsetting entry, never an edit or delete of a historical one.
This directly operationalizes what `testing-agent` is already supposed to
verify.

---

## Gap 4 — No localization/RTL guidance anywhere in `CORE_SYSTEM/`

**Current state:** `FLUTTER_STANDARDS.md` doesn't mention `intl`, RTL
support, or `Directionality` at all. This wasn't a gap for the existing
portfolio if those apps are English/LTR-only, but it's a foundational
requirement for this project (see `ENGINEERING_REVIEW.md` F4) and plausibly
for any future Egypt/MENA-market app.

**Recommended improvement:** add a short "Localization" subsection to
`CORE_SYSTEM/FLUTTER_STANDARDS.md` — use `intl` for all user-facing
strings and number/currency formatting from the first screen (never
hardcode strings "to localize later"), and treat RTL support as a layout
decision made at project start (`Directionality`-aware widgets, avoid
manually-mirrored icons) rather than a retrofit. This is a small, portfolio-
wide addition, not a pharmacy-specific hack.

---

## Non-gap, flagged for awareness — e-invoicing compliance work needs a human gate the OS doesn't currently model

`AGENT_BEHAVIOR.md`'s pipeline (understand → plan → implement → validate)
assumes any ambiguity can be resolved by "ask one question, or state an
assumption and proceed." That's the right default for engineering
ambiguity. It is not the right default for a question like "does this
revenue threshold trigger a legal e-receipt obligation" — an agent stating
an assumption and proceeding here is a liability, not a productivity gain.

**Recommendation:** not a system change. Handle this at the project level —
add a `COMPLIANCE.md` to this project only (see `PROJECTS/_TEMPLATE`
extension below), and treat anything touching it as out of scope for
`AGENT_BEHAVIOR.md` step 1's "state the assumption and proceed" — it
requires an explicit human/legal confirmation logged in that file before
`architect-agent` produces a plan. This is a one-off addition to this
project's own template usage, not a `CORE_SYSTEM/` rule, since most future
portfolio apps won't carry this kind of regulatory exposure.

---

## Recommended additions to `PROJECTS/_TEMPLATE` usage for this project

The existing six per-project files (`AGENTS.md`, `ARCHITECTURE.md`,
`PROJECT_MEMORY.md`, `DECISIONS.md`, `SECURITY.md`, `FEATURES.md`) are
sufficient for the rest of the portfolio. For this project specifically,
add one file — not a `_TEMPLATE` change, since most future apps won't need
it:

- **`COMPLIANCE.md`** — tracks regulatory items (e-invoicing/ETA threshold
  and format, data-residency if it ever comes up) with a status per item:
  unconfirmed / confirmed-by-counsel / implemented. Referenced by
  `architect-agent` before any plan touching a `COMPLIANCE.md`-tracked item,
  per the gate above.

---

## Summary of changes to make before Sprint 0

| File | Change | Scope |
|---|---|---|
| `CORE_SYSTEM/SECURITY_STANDARDS.md` | Tighten the local-data-layer authorization exception | Portfolio-wide |
| `CORE_SYSTEM/FLUTTER_STANDARDS.md` | Add "Financial data" subsection | Portfolio-wide |
| `CORE_SYSTEM/FLUTTER_STANDARDS.md` | Add "Localization" subsection | Portfolio-wide |
| `PROJECTS/pharmacy-saas/ARCHITECTURE.md` | Add local-vs-remote schema note | Project-only |
| `PROJECTS/pharmacy-saas/COMPLIANCE.md` | New file, regulatory tracker | Project-only |

No new agents, no new skills, no MCP server list changes — the existing
system's coverage is good; it just needs these five targeted edits before
it's safe to point at this specific project.
