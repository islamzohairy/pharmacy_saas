# Pharmacy Profit Control Platform — Project Rules

Global rules (`CORE_SYSTEM/`) are already loaded automatically via
`instructions` in `~/.config/opencode/opencode.json` — don't duplicate them
below. Only project-specific rules go here. This file is the one thing
OpenCode loads automatically every session; everything else in this folder
is read manually per `AGENT_BEHAVIOR.md` step 5 — the "Where to look
first" list below exists so that manual step doesn't miss anything.

## What this app is
A mobile-first business-management app for independent pharmacy owners in
Egypt. P0 answers four confirmed problems: where the money goes, supplier
debt, cash draws mixed with income, and customer debt. Android-only for
now, Arabic-primary/RTL, local-first with best-effort backup sync to a
Supabase backend. Single-owner, single-device pilot — no employee accounts
yet.

## Constraints specific to this app
- No backend authentication in P0 — identity is a local device profile
  (see `ARCHITECTURE.md`). Don't add a login/password/OTP flow unless a
  `DECISIONS.md` entry says that's changed.
- Multi-tenant backend (Supabase/Postgres + RLS) even though P0 has one
  tenant per install — tenant isolation (`pharmacy_id`) is load-bearing
  from the first migration, not a later retrofit.
- Money is always integer minor units (piastres), never float. The ledger
  (`ledger_entries`) is append-only — no update/delete path, ever. See
  `ARCHITECTURE.md` and `PLANS/03_DATA_AND_SYNC_PLAN.md`.
- Arabic-primary, RTL-first UI from the first screen — not a retrofit.

## State management in use
Riverpod, hand-written providers (matches the global default in
`FLUTTER_STANDARDS.md` — no deviation). Rationale for staying on the
default despite this being a money-movement app is recorded in
`DECISIONS.md` (the audit-trail need is met by the ledger design, not by
switching state management).

## Standing rule — schema migrations (PLANS/11 §8)
- Never edit an applied migration in place (neither the remote
  `supabase/migrations/` SQL nor the drift `onUpgrade` steps that shipped
  in a released version). Schema changes are always a NEW additive
  migration + a `schemaVersion` bump.
- Every release that ships a local `schemaVersion` bump must rehearse the
  migration against a copy of REAL pilot data before release, and record
  the rehearsal (data source, before/after counts) in `DECISIONS.md` —
  fixture-seeded verification is not a rehearsal. See
  `SUPPORT_AND_ROLLBACK.md` §5.3.
- Remote schema changes additionally require the deploy gate: migration
  applied to the live project + `rls_isolation_test.sql` re-run green,
  user-confirmed, before any build pushing the new wire format ships.

## Discovery and scope control (user directive 2026-08-03)
Applies to every plan in this project:
- Follow the existing plan instructions first. Do not expand scope or
  change the implementation direction based on discoveries without
  reporting them and getting confirmation.
- New findings triage:
  - Required to satisfy the existing plan/DoD → proceed, and document
    the reason in `DECISIONS.md`.
  - Changes scope, architecture, or previous decisions → stop and ask
    first.
  - Keep every deviation recorded in `DECISIONS.md`.
Why this lives here and not in CORE_SYSTEM: the rule depends on this
project's PLANS/DECISIONS/FEATURES workflow — see `DECISIONS.md`
2026-08-03 entry.

## Where to look first
- `ARCHITECTURE.md` — structure and key decisions in force
- `PROJECT_MEMORY.md` — durable facts a fresh session needs
- `DECISIONS.md` — append-only decision log, newest at the bottom
- `SECURITY.md` — this app's actual threat model
- `COMPLIANCE.md` — regulatory items (e-invoicing/ETA) and their
  confirmation status — **check this before touching anything e-invoicing/
  ETA-related; anything not marked `confirmed-by-counsel` is not a normal
  backlog item, see the file itself**
- `FEATURES.md` — roadmap and current status, with a pointer to the active
  `PLANS/` file for whatever's in progress
- `PLANS/01`–`08` — the sequenced P0 implementation plans, one per feature
  area, meant to be read in order (each states its own dependencies).
  Read only the plan you're actively implementing — don't load all eight
  into context at once.
- `ENGINEERING/` — the original strategy and review documents these
  template files were distilled from. Historical/reference only; not
  needed for day-to-day feature work. Read `ENGINEERING/
  ENGINEERING_STRATEGY.md` if `ARCHITECTURE.md` doesn't answer a "why"
  question in enough depth.
