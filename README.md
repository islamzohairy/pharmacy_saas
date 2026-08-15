# NoNota (نونوتا) — Project Workspace

Brand: **NoNota (نونوتا)** — بديل الدفتر لصاحب المحل الصغير. Horizontal
small-retail product; pharmacies are the first pilot vertical. Locked brand
record and Play-listing strings live in `product/BRAND_AND_ASO.md`. Internal
schema naming (`pharmacies`/`pharmacy_id`) is a retained legacy tenant label,
not a product statement.

This folder is a project under `ai-engineering-os/PROJECTS/`, built from
`_TEMPLATE`. If you haven't read the top-level `ai-engineering-os/README.md`
yet, do that first — this file only covers what's specific to this project.

## What actually gets loaded automatically, and what doesn't
OpenCode auto-loads two things every session: the global
`~/.config/opencode/AGENTS.md` (which points at `CORE_SYSTEM/`) and this
project's own `AGENTS.md`. **Nothing else in this folder loads itself** —
`ARCHITECTURE.md`, `PROJECT_MEMORY.md`, `DECISIONS.md`, `SECURITY.md`,
`COMPLIANCE.md`, `FEATURES.md`, and everything under `ENGINEERING/` and
`PLANS/` are read manually, per `AGENT_BEHAVIOR.md` step 5 and
`DAILY_WORKFLOW.md`'s session-start habit. `AGENTS.md`'s "Where to look
first" section is the map — start there if this README doesn't answer your
question.

## Folder contents

| File/folder | What it is | When to read it |
|---|---|---|
| `AGENTS.md` | Project rules, auto-loaded every session | Automatic |
| `ARCHITECTURE.md` | Current-state architecture — the distilled answer | Every session touching structure/schema |
| `PROJECT_MEMORY.md` | Durable facts, kept current (edited in place) | Every session, especially a fresh one |
| `DECISIONS.md` | Append-only log of *why* — never edited, only appended | When a past decision might be relevant, or before reversing one |
| `SECURITY.md` | This app's actual threat model and controls | Anything touching auth/storage/network/PII |
| `COMPLIANCE.md` | Regulatory items and their confirmation status | Before any e-invoicing/ETA work — this is a hard gate, not a normal backlog item |
| `FEATURES.md` | Roadmap, current status, which `PLANS/` file is active | Every session — tells you what's next |
| `PLANS/01`-`08` | Sequenced, detailed implementation plans for P0 | Open only the one you're actively building |
| `ENGINEERING/` | Original strategy + review docs these templates were distilled from | Reference only, for "why" questions `ARCHITECTURE.md` doesn't answer in enough depth |
| `opencode.json` | Per-project config — deliberately empty `instructions`, see the file's own comment | Rarely |

## Why `PLANS/` and `ENGINEERING/` exist as separate tiers
`ARCHITECTURE.md`/`PROJECT_MEMORY.md`/`SECURITY.md`/`FEATURES.md` are the
**current-state** files — short, kept accurate, read every session, exactly
as `MEMORY_RULES.md` intends. `PLANS/` and `ENGINEERING/` are **historical/
reference** — written once, not rewritten to "stay current." If a plan
turns out to be wrong or superseded once implementation starts, don't
silently edit the plan file: log the deviation in `DECISIONS.md` the same
way the OS already handles any superseded decision, and update
`FEATURES.md`'s status line. The plan file stays as a record of the
original intent.

## Build order
`PLANS/01` through `08`, in order — each plan's own "Dependencies" section
states exactly what must exist before it starts, so this isn't an
arbitrary numbering. `FEATURES.md`'s roadmap table is the live pointer to
which one is current.

## The one gate that isn't optional
Anything touching e-invoicing/ETA compliance is blocked on `COMPLIANCE.md`
showing `confirmed-by-counsel` for that item — not on an agent's stated
assumption, per `AGENT_BEHAVIOR.md`'s normal ambiguity rule, which
deliberately does not apply here. See `COMPLIANCE.md` for why.

## First-time setup for this project
```
cp -r ai-engineering-os/PROJECTS/pharmacy-saas /path/to/your/dev/folder/
cd /path/to/your/dev/folder/pharmacy-saas
flutter create . --org com.yourcompany
opencode
```
Then start with `PLANS/01_PROJECT_FOUNDATION_PLAN.md`.
