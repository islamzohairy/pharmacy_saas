# Engineering Strategy — Pharmacy Profit Control Platform

Scope: technical direction for the P0 MVP defined in
`pharmacy_saas_product_specification-2.md` §10-11, informed by the findings
in `ENGINEERING_REVIEW.md`. This is the document every implementation plan
in this package is built from — read it first.

## 1. Platform strategy

**MVP platform: Android only.**

**Reasoning:** device/OS mix is an explicit Tier 3 open question (spec §20
item 6) — genuinely unconfirmed, not assumed. Android-first is the
reasonable default while that's being validated, not a settled fact: it
reflects Android's dominant historical share of the Egyptian smartphone
market and lets one platform's build/release/testing surface absorb the
early pilot cycles instead of splitting effort. This should be one of the
questions confirmed alongside the Sprint 0 interviews (spec §16); if the
answer comes back mixed, iOS moves onto the roadmap immediately rather than
waiting for a "future platforms" review point.

**Future platforms:**
- **iOS** — as soon as Sprint 0 confirms meaningful iOS presence in the
  segment. Flutter's shared codebase means this is a build/store-listing
  cost, not a rewrite, provided the codebase hasn't taken Android-specific
  shortcuts (Material-only widgets used as if they were universal, no
  platform-adaptive checks). Keep `Platform.isAndroid` branches out of
  business logic from day one so this stays cheap.
- **Web (admin/reporting)** — plausible V4+ companion to the multi-branch
  roadmap item (spec §17), not a consumer-facing MVP need. Defer entirely
  until multi-branch is validated.
- **Desktop** — not justified by any current or plausible persona. Not
  planned.

**What's shared vs. platform-specific:** all domain logic, business rules,
the ledger model, and repository/data-layer code are 100% shared (Flutter
+ Dart across whatever platforms ship). UI composition, platform channel
work (if any), and navigation chrome are the only platform-specific layer.

## 2. Offline-first: recommendation and reasoning

**Decision:** hybrid — **local-first for all writes, best-effort background
backup, not full multi-device sync.**

**Reasoning:** per `ENGINEERING_REVIEW.md` F1, offline-first was asserted in
the source spec without direct customer evidence on connectivity. Rather
than defaulting to either extreme (full offline-first sync engine, or a
naive "assume good connectivity, write straight to a server" design), the
right MVP-stage answer is the one that's cheap now and doesn't foreclose
either direction later:

- All writes go to the local database first and always succeed locally
  regardless of connectivity — a sale entry must never block on network,
  because the whole point of the product is that she logs it *in the
  moment*.
- A background job pushes new ledger entries to the remote backend
  opportunistically (app foreground + connectivity present). This solves
  the actual confirmed risk (F5 — data loss if the phone is lost) without
  building conflict resolution for concurrent multi-device writes, which
  isn't needed yet: the confirmed persona (spec §6) is single-device,
  effectively single-writer-at-a-time (she and her father share shifts, not
  simultaneous sessions).
- **Explicitly deferred, not built:** real-time sync, multi-device
  simultaneous editing, and conflict resolution beyond simple
  last-write-wins-per-record. Revisit if Sprint 0/ICP-B interviews confirm
  a multi-device or true multi-employee need.

**Alternatives considered:**
- *Pure offline, no backend at all* — cheapest to build, but leaves F5
  (data loss) completely unaddressed. Rejected: the product's core promise
  can't survive losing its own data.
- *Online-first, server as source of truth* — simplest mental model, but
  makes every write latency- and connectivity-dependent, which is a
  regression risk given connectivity is explicitly unconfirmed and the
  product's core loop (logging a sale, a draw) needs to feel instant.
  Rejected for the confirmed use case.

**Future impact:** this shape scales cleanly into full sync later — the
local-first write path doesn't change; only the background job gains
conflict-resolution logic once multiple concurrent writers are confirmed.

## 3. Backend

**Decision: Supabase (managed Postgres + Auth + Storage), not a hand-rolled
service.**

**Reasoning:** the actual backend surface for P0 is small — receive backup
writes, enforce tenant isolation, hold the eventual billing/subscription
state. Supabase gives Postgres (strong relational/transactional guarantees,
which matter for a ledger) with Row-Level Security for `pharmacy_id`
tenant isolation enforced server-side (closing Gap 2 from
`AI_ENGINEERING_OS_REVIEW.md`), a maintained Auth service for whenever real
authentication is confirmed needed, and a cost profile appropriate for
"low-cost SaaS" at pilot scale. This also matches `SECURITY_STANDARDS.md`'s
existing guidance to use a maintained auth provider rather than rolling
one.

**Alternatives considered:** Firebase (Firestore's document model is a
weaker fit for ledger-style relational queries and aggregation than
Postgres); a custom Node/Express + Postgres service (more control, but pure
overhead at this stage — no requirement here that a managed platform can't
satisfy, and it's a maintenance burden for a solo/small team).

**Tradeoffs:** vendor dependency on Supabase; acceptable at this stage
given Postgres underneath means a future migration off Supabase is a data
export problem, not a data-model rewrite.

## 4. State management, DI, navigation

**State management: Riverpod, hand-written providers — no change from the
AI Engineering OS default.**

The OS's `FLUTTER_STANDARDS.md` flags Bloc as the right call when a project
"genuinely needs strict event/state audit trails (e.g. handling money
movement with compliance requirements)" — which sounds like exactly this
project. It's a real consideration, so it's addressed explicitly rather
than silently defaulted past:

**Decision:** stay on Riverpod. **Reason:** the audit-trail need this
project actually has is a *data-layer* property (an immutable, append-only
ledger — §5 below), not a *state-management* property. Bloc's event-sourcing
style would give an audit trail of UI-triggered events; what this product
needs is an audit trail of financial facts, which the ledger design
provides regardless of what manages widget state above it. Switching state
management to solve a data-layer problem adds real cost (breaks portfolio
consistency across [[wormag-app]], [[savings-app]], [[fitness-app]], all on
Riverpod; steeper AI-agent output consistency, per the OS's own reasoning
for pinning approaches) without solving anything Riverpod-plus-a-real-
ledger doesn't already solve. **Alternatives considered:** Bloc (rejected,
above). **Future impact:** none — this isn't a one-way door; nothing about
the ledger design depends on the state-management choice above it.

**DI:** Riverpod providers, no separate DI framework — OS default, no
project-specific reason to deviate.

**Navigation:** `go_router`. P0 has ~7-8 screens (profile/onboarding,
product entry, sales entry, draw logging, supplier debt, customer debt,
dashboard) — no deep-linking need yet, but `go_router` costs nothing extra
now and avoids a navigation-library migration if a future web admin surface
needs shareable URLs.

## 5. Data layer & database

**Local:** `drift` over raw `sqflite`. Reasoning: compile-time-checked
queries and structured migrations are worth the setup cost specifically
*because* this is a money-correctness-sensitive app — a hand-written SQL
typo in a balance query is exactly the failure mode Gap 3 exists to
prevent, and `drift` catches a class of these at compile time that raw
`sqflite` can't.

**Remote:** Postgres via Supabase, same logical schema shape as local,
reconciled by the sync job (§2).

**Core entities (see `03_DATA_AND_SYNC_PLAN.md` for full schema):**
`Pharmacy` (tenant root), `UserProfile` (role: owner / family / employee —
data model ships now per `ENGINEERING_REVIEW.md` F2, enforcement logic
deferred), `Product` (cost/sell price, optional expiry date),
`LedgerEntry` (typed: sale / draw / supplier_debt / customer_debt /
repayment — append-only, immutable, integer minor-unit amounts),
`Supplier`, `Customer`.

**Repository pattern** at the domain/data boundary per the OS default —
this is what makes the local-vs-remote split in §2 a data-layer-only
concern; domain code never knows which store it's talking to.

**Migration strategy:** `drift`'s generated migration steps for local;
standard Postgres migrations (Supabase CLI) for remote, tracked in lockstep
per `AI_ENGINEERING_OS_REVIEW.md` Gap 1 — every schema-touching plan states
which side(s) it changes.

## 6. Security

- **Authentication:** none required for P0 (see `ENGINEERING_REVIEW.md`
  F2) — a local device-level profile with an optional PIN, secured via
  `flutter_secure_storage`, not a backend login. Real Supabase Auth
  (phone-OTP is the common pattern for this market) is added only once a
  multi-device or true-employee need is confirmed.
- **Authorization:** enforced server-side via Postgres Row-Level Security
  scoped to `pharmacy_id` for anything that reaches the backend — even
  though P0 has no multi-user backend access yet, RLS is configured from
  the first migration so it's not retrofitted onto live tenant data later.
- **Local storage:** encrypted at rest (`sqlcipher` via `drift`) — explicit
  decision, not silence, per `SECURITY_STANDARDS.md`'s own requirement that
  encryption-at-rest be a recorded decision either way. Justified here
  given the data is a full financial history of a small business.
- **Transport:** TLS to Supabase by default (managed).
- **Certificate pinning:** not applied for P0 — proportionate call per
  `SECURITY_STANDARDS.md`; revisit if/when card payment data ever flows
  through the app directly (it shouldn't — route payments through a
  compliant processor per `ENGINEERING_REVIEW.md` minor notes).
- **Compliance:** e-invoicing/ETA work is gated behind `COMPLIANCE.md`
  confirmation per `AI_ENGINEERING_OS_REVIEW.md` — no implementation plan
  exists for it yet, deliberately.

## 7. Performance

Single-pharmacy data volumes are small (hundreds to low thousands of ledger
rows per year) — performance risk for P0 is low. The only concrete
requirement: index `LedgerEntry` by `(pharmacy_id, occurred_at)` and by
`type`, since the dashboard's aggregation queries filter on both. Revisit
if/when multi-branch aggregation (V4+) needs to roll up across pharmacies.

## 8. Localization

Arabic-primary, RTL-first from the first screen, per
`ENGINEERING_REVIEW.md` F4 and the corresponding
`CORE_SYSTEM/FLUTTER_STANDARDS.md` addition in `AI_ENGINEERING_OS_REVIEW.md`
Gap 4. All user-facing strings through `intl` from day one; currency
formatted as EGP with locale-correct grouping. English as a secondary
locale toggle is plausible future scope, not P0.

## 9. Design patterns actually used, and why

- **Repository pattern** — justified: it's the entire mechanism that makes
  the local/remote split (§2, §5) a data-layer concern instead of a
  domain-wide one.
- **Ledger (event-sourcing-flavored) pattern for money** — justified: solves
  the concurrency and auditability problem in `ENGINEERING_REVIEW.md` F3
  directly; a mutable-balance alternative doesn't.
- **No DI framework, no Strategy/Factory abstractions beyond what Riverpod
  and the repository interfaces already provide** — deliberately not
  added; nothing in P0 has more than one real implementation to swap, so
  added abstraction would be speculative generality, which
  `CODE_REVIEW_RULES.md` already flags as a review failure.

## 10. What this strategy deliberately does not decide yet

Pricing/billing integration, multi-branch data-rollup shape, employee
enforcement logic, expiry alerting logic, and e-invoicing implementation —
all correctly sequenced to P1+ in the source spec, and none of them are
blocked by anything decided above. The schema hedges already in place
(optional expiry field, role column, `pharmacy_id` tenant key) mean none of
these require a data-model rewrite when they're confirmed.
