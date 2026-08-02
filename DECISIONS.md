# Decisions — Pharmacy Profit Control Platform

Append-only. Newest entry at the bottom. Never delete an entry — if a
decision is reversed, add a new entry that says so and references the old
one. Tag lesson-learned entries with `lesson:`.

Format per entry:
```
## <date> — <short title>
DECISION: <what was decided>
WHY: <the actual reason, not just "best practice">
ALTERNATIVES CONSIDERED: <if any>
```

<!-- entries go below -->

## 2026-08-02 — Backend: Supabase over Firebase or a custom service
DECISION: Managed Supabase (Postgres + Auth + Storage) as the remote
backend.
WHY: Postgres's relational/transactional guarantees fit a ledger better
than Firestore's document model; Row-Level Security gives server-side
tenant isolation for free; cost profile fits a low-cost SaaS at pilot
scale; a maintained auth provider is already required by
`SECURITY_STANDARDS.md`.
ALTERNATIVES CONSIDERED: Firebase (weaker fit for relational
aggregation queries); custom Node/Postgres service (pure maintenance
overhead at this stage, no requirement Supabase can't satisfy).

## 2026-08-02 — Identity: local device profile, no backend auth for P0
DECISION: P0 identity is a local device profile with an optional PIN — no
server-side accounts, login, or session tokens.
WHY: the confirmed pilot persona (real interview, n=1) is single-device,
single-owner, no employees. Building auth infrastructure ahead of that
evidence mirrors the exact reasoning error the product spec itself warns
against (treating an unconfirmed need as either confirmed-present or
confirmed-absent) — applied here to the engineering side. The `role`
column ships now on `UserProfile` so enforcement is a fast-follow, not a
schema rewrite, once ICP-B or a real employee need is confirmed.
ALTERNATIVES CONSIDERED: full Supabase Auth from day one (rejected —
no confirmed need, adds backend dependency to the critical path for the
first pilot).

## 2026-08-02 — Money model: append-only ledger, integer minor units
DECISION: all money stored as integer minor units (piastres); all
financial facts stored as immutable, append-only `LedgerEntry` rows;
balances (profit, amount owed) always computed live by aggregation, never
stored as a mutated running total.
WHY: floating-point currency drifts silently over volume; a mutable
balance field isn't safe against the confirmed shift-handoff pattern
(she and her father share a device across shifts) and produces a number
nobody can audit when it's wrong — unacceptable for a product whose entire
value proposition is "know where your money goes."
ALTERNATIVES CONSIDERED: mutable balance field updated per transaction
(rejected — concurrency and auditability risk, see above).

## 2026-08-02 — State management: staying on Riverpod despite the
Bloc-for-money-movement guidance in FLUTTER_STANDARDS.md
DECISION: Riverpod, hand-written providers — no deviation from the
portfolio default.
WHY: `FLUTTER_STANDARDS.md` flags Bloc as the right call for apps needing
strict event/state audit trails, which sounds like this app. Evaluated
explicitly: the audit-trail need here is a data-layer property (the
append-only ledger above), not a state-management property. Bloc would
audit UI-triggered events; the ledger already audits financial facts,
regardless of what manages widget state above it. Switching would cost
portfolio consistency without solving anything the ledger design doesn't
already solve.
ALTERNATIVES CONSIDERED: Bloc (rejected, reasoning above).

## 2026-08-02 — Platform: Android-first
DECISION: P0 targets Android only.
WHY: device/OS mix in the target segment is an explicit open question in
the product spec, not a confirmed fact. Android-first reflects Android's
dominant historical share of the Egyptian smartphone market as a
reasonable default while that's being validated directly in the Sprint 0
interview pass, not a settled architectural fact.
ALTERNATIVES CONSIDERED: build both platforms from day one (rejected —
doubles build/release/testing surface with no confirmed iOS demand yet).

## 2026-08-02 — Local database: drift over raw sqflite
DECISION: use `drift` for local persistence.
WHY: compile-time-checked queries and structured migrations catch a class
of bugs raw `sqflite` can't — justified specifically because this app is
money-correctness-sensitive; a hand-written SQL typo in a balance query is
exactly the failure mode the ledger design (see above) exists to prevent.
ALTERNATIVES CONSIDERED: raw `sqflite` (rejected — no compile-time query
safety).
