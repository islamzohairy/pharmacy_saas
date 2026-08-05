# PLANS/11_PILOT_HARDENING_AND_OBSERVABILITY_PLAN.md

**Plan:** 11 — Pilot Hardening & Observability
**Owner:** Staff Engineer AI
**Executor:** Builder AI (single execution cycle)
**Status:** Approved — ready for execution
**Dependencies:** Plans 01–10 on `main` (159 tests green baseline)
**Remote impact:** None — this plan is local-only; no changes under `supabase/`

---

## 1. Objective

**What is being built:** Make failure visible and non-destructive before the first pilot install. Three deliverables:

1. **Anti-bricking guarantee:** verified, tested proof that a failed database open/migration never destroys or deletes the pilot user's data, and surfaces a recoverable error state.
2. **Backup staleness observability:** the existing dashboard backup indicator gains a *stale* state — "you have records that have not been backed up for N days" — derived from existing sync state, with Arabic-first RTL copy.
3. **Pilot operations & release discipline:** the operational protocol appended to `SUPPORT_AND_ROLLBACK.md`, a new `RELEASES.md` with version-tag → rollback mapping, and the standing schema-migration rule recorded in `AGENTS.md`.

**Why it matters:** The priority order is business data correctness → pilot stability → UX → sync reliability. This plan serves the first two directly. The closed pilot proceeds on operational controls (confirmed risk classification); those controls only work if (a) the app cannot brick a pilot device, and (b) silent backup failure is impossible — the operator must *see* it. Everything else (export/import, guaranteed scheduling, automatic crash collection) is deliberately deferred to Plans 12–13.

## 2. Current Problem — Evidence

| # | Evidence | Source |
|---|---|---|
| 1 | Migration `0002` backfill "verified via raw-seeded fixtures only — no real pilot DB copy available for migration testing" | Plan 10 commit record |
| 2 | The DB-open failure path (failed `onUpgrade`, corrupt file) is not documented as tested anywhere in `FEATURES.md` | `FEATURES.md` plans 01–10 review |
| 3 | Backup model is one-way best-effort with an in-app status indicator, but no documented *staleness* signal — a scheduler killed by OEM battery optimization produces no user-visible warning | `ARCHITECTURE.md` sync model; risk finding R3 |
| 4 | `FEATURES.md` release history: "None yet" — pilot builds will start soon with no tag/rollback mapping in place | `FEATURES.md` |
| 5 | Standing gap from `AI_ENGINEERING_OS_REVIEW.md`: no enforced migration-rehearsal rule | Staff review, this cycle |

## 3. Scope

**Included:**
- Phase 0 verification of five spot-checks (DB-open path, money types, scheduler wiring, `watchEntries(limit:)` usage, ledger query paths).
- Hardening of the DB-open/migration failure path **only if Phase 0 finds it defective**; otherwise documented proof it is sound.
- Backup staleness state on the existing dashboard indicator (derived signal preferred; minimal additive persistence only as fallback).
- Documentation: `SUPPORT_AND_ROLLBACK.md` § pilot operations protocol, new `RELEASES.md`, migration rule in `AGENTS.md`, plus the standard `FEATURES.md` / `PROJECT_MEMORY.md` / `DECISIONS.md` updates.

**Excluded (explicitly — do not let scope creep in):**
- Export/import of any kind → Plan 12.
- `workmanager` / `BGTaskScheduler` / any background-execution plugin or platform channel → Plan 13.
- Automatic crash reporting / Sentry → later plan, pre-production.
- Any change under `supabase/` — this plan is **local-only**; no remote schema migration, no RLS re-test needed.
- New routes, new hub tiles, new product features, analytics.
- Supabase Auth or any account-related work.

## 4. Technical Design

### 4.1 Phase 0 — Verification gate (read-only; no code changes)

Builder AI reads and records findings for:

| Check | Files to inspect | Pass criteria |
|---|---|---|
| V1 — DB open/migration failure path | `lib/core/data/` database connection setup (drift `AppDatabase`, connection wiring from Plan 01), `lib/main.dart` | A throwing `onUpgrade` or a corrupt file results in a surfaced error, **never** file deletion/recreation |
| V2 — money types | grep across `lib/` for `double` in any amount path; review `core/format/money.dart` (`formatEgp` / `parseEgpToMinor`) | All amounts are integer minor units end-to-end |
| V3 — scheduler wiring | `lib/core/data/sync/` | Triggers match docs: start / foreground-resume / write-debounce / 60s periodic / exponential backoff |
| V4 — `watchEntries(limit:)` usage | ledger repository + call sites | `limit` used only by the activity feed; dashboard aggregation unbounded |
| V5 — ledger query paths | ledger repository queries + drift table definitions | The unsynced-tracking mechanism (flag or watermark) is identified; query paths used by dashboard/indicator are indexed or provably small |

**Stop conditions (Major Change Rule):** if V1 reveals data destruction on failure, or V2 reveals `double` in money paths, or V3 reveals material divergence from documented behavior → **stop, report to Staff Engineer, do not proceed**. These become a `MAJOR_CHANGE_PROPOSAL.md`, not an inline fix. Minor divergences get fixed in-phase and logged in `DECISIONS.md`.

### 4.2 Backup staleness — derived-signal-first design

**Design decision (record in `DECISIONS.md`):** staleness is *derived*, not *stored*, whenever the existing sync-state mechanism allows it. Preference order:

1. **If V5 finds an unsynced flag/watermark:** stale ⇔ ∃ unsynced ledger entry older than threshold. `threshold = 48 hours` (record rationale: daily-use pilot; two missed days is already a support conversation). This requires **zero schema change**.
2. **Fallback only if no derivable signal exists:** one additive, local-only drift table (`sync_metadata`, single row, `last_successful_push_at`), written by the push-success path. Additive-only migration v6 — the safest migration class. **Never** modify `0001`/`0002` or the drift equivalents in place.

**UI state machine** on the existing dashboard bottom-bar indicator (alongside `ErrorLogIndicator`):

| State | Condition | Presentation |
|---|---|---|
| healthy | no unsynced entries | current behavior, unchanged |
| pending | unsynced entries, all fresh | current behavior, unchanged |
| **stale (new)** | unsynced entries older than threshold | warning visual + Arabic copy ("آخر نسخة احتياطية قديمة — تحقق من الاتصال") — tap → explanation dialog (what it means, what to do), no destructive actions in the dialog |
| empty | zero ledger entries | never stale — nothing to lose; no alarm |

All copy through `intl`, RTL-correct, consistent with Plan 09 indicator conventions.

### 4.3 DB-open hardening (conditional on V1)

If V1 fails, the fix shape is fixed here so Builder AI doesn't improvise:

- Catch open/migration failure at the connection boundary.
- **Never** delete, move, or recreate the database file.
- Surface a dedicated non-destructive fatal-error screen: Arabic explanation, "copy report" action reusing the Plan 09 plain-text-report mechanism **where it can function without the DB open** (file-path + error text; no ledger content), and support contact guidance.
- The failure must also be chain-reported through the existing error-handling zone so it lands in whatever capture path is available.
- No automatic retry loops; user-triggered retry only.

### 4.4 Multi-platform distinction (binding for this plan)

| Layer | Rule in this plan |
|---|---|
| **Android pilot requirement** | Runtime verification happens on the Android emulator/device; stale-state copy is validated in RTL on an Arabic locale device. Platform-specific behavior is *not* introduced. |
| **Cross-platform architecture** | All new logic is pure Dart + drift + existing Riverpod providers. No platform channels, no plugins, no Android APIs anywhere in this plan. Staleness derivation lives in the sync/core data layer behind the existing repository boundary — the same seam Plan 13's `SyncScheduler` interface will use. |
| **Future platforms** | Nothing in this plan constrains iOS/desktop/web. If the fallback `sync_metadata` table is needed, it is plain drift — portable by definition. |

## 5. SOLID Application

- **S:** staleness evaluation is one pure, testable function (threshold + unsynced-age → state). UI renders state; it never computes it.
- **O:** the indicator's state set is extended without touching the healthy/pending paths.
- **L/D:** dashboard depends on the existing provider contract only; no new concrete dependencies into widgets.
- **I:** the stale signal is exposed through the existing backup-status provider surface — no new god-provider.
- **Feature rule:** any shared widget/provider access stays through feature barrels; no cross-feature internal imports (per `ARCHITECTURE.md`).

## 6. File Impact (expected; confirm exact paths in Phase 0)

| File | Status | Responsibility |
|---|---|---|
| `lib/core/data/sync/` (staleness derivation) | Modified | Pure staleness function + provider exposure |
| dashboard bottom-bar indicator widget (Plan 03/09 area) | Modified | Third visual state + dialog |
| `lib/l10n/` arb files | Modified | New Arabic strings |
| DB connection setup in `lib/core/data/` | Modified **only if V1 fails** | Non-destructive failure handling |
| drift schema + new migration | New **only if fallback needed** | `sync_metadata` table |
| `SUPPORT_AND_ROLLBACK.md` | Modified | § Pilot Operations Protocol |
| `RELEASES.md` | New | Tag convention + mapping table |
| `AGENTS.md` | Modified | Standing schema-migration rule |
| `FEATURES.md`, `PROJECT_MEMORY.md`, `DECISIONS.md` | Modified | Standard closure updates |
| `test/` | Modified | New unit + widget tests below |

## 7. Implementation Steps (ordered)

1. **Phase 0 — Verification report.** Execute V1–V5. Write findings into the PR description and append a dated entry to `DECISIONS.md`. Apply stop conditions.
2. Record the staleness-derivation decision (derived vs fallback) in `DECISIONS.md` with the evidence from V5.
3. If V1 failed: implement 4.3, then its tests, before any other code.
4. If fallback needed: additive migration + table + repository access. Otherwise: skip.
5. Implement the staleness function + provider exposure in the sync layer; unit-test first.
6. Extend the indicator widget with the stale state + dialog; widget-test all four states in RTL.
7. Add l10n strings; verify Arabic rendering.
8. Write `RELEASES.md`; append the operations protocol to `SUPPORT_AND_ROLLBACK.md`; add the migration rule to `AGENTS.md`.
9. Update `FEATURES.md` / `PROJECT_MEMORY.md` / `DECISIONS.md`.
10. Full gate: analyzer clean, entire suite green, release-mode runtime pass on the emulator (fresh install → record entries → observe states), CI green.

## 8. Dependencies

- No code dependencies on other plans.
- No Supabase changes → **no deploy gate / live RLS re-test required** for this plan.
- Requires the existing Plans 01–10 state on `main` (159 tests green baseline).

## 9. Testing Strategy

| Layer | Tests |
|---|---|
| **Unit** | Staleness function: no entries → healthy; fresh unsynced → pending; unsynced > 48h → stale; exactly-at-threshold boundary; watermark-vs-flag parity if applicable. If V1 fix lands: failing migration → file untouched, error surfaced, retry path works. Money-path audit result recorded as evidence. |
| **Widget** | Indicator renders all four states; stale tap opens dialog; RTL layout with `ErrorLogIndicator` present simultaneously; Arabic copy renders. Use the existing `unmountAndFlushDriftTimers` helper (Plan 07 lesson) for any test navigating away from drift-watching screens. |
| **Integration / migration** | If fallback table added: v5→v6 migration test on a seeded v5 fixture DB. Regardless: fresh-install path test. |
| **Runtime** | Release-mode emulator pass: full P0 flow still exact (dashboard figures regression check), stale state reproducible by seeding an old unsynced entry. |

## 10. Edge Cases

- Device clock changed backward/forward: staleness compares entry timestamps to `DateTime.now()` — document in `DECISIONS.md` that clock manipulation can mask staleness; accepted residual risk for pilot.
- First launch / empty ledger: never stale.
- Both indicators active (errors + stale backup): bottom bar must remain readable in RTL; no overlap, no clipping.
- DB open failure with zero crash-capture availability: the fatal-error screen itself is the fallback surface (no dependency on `error_log_entries` being writable).

## 11. Security Considerations

- No new network surface, no new credentials, no change to the device-token model.
- New log/dialog text must contain **no ledger content, no token material** — state and timestamps only.
- The fatal-error report reuses Plan 09's clipboard mechanism; keep it content-minimal.

## 12. Performance Considerations

- Derived staleness must reuse existing sync-state streams; no new periodic full-table scan. If an "oldest unsynced" query is needed, it must be indexed and bounded, and must not touch the dashboard aggregation path.
- Threshold evaluation runs on state changes (write-debounce / scheduler ticks), not on a new timer.

## 13. Acceptance Criteria

1. Phase 0 report exists with all five checks concluded; any stop-condition finding escalated, not fixed inline.
2. A pilot device **cannot** be bricked by a failed open/migration — proven by a failing test that asserts the file survives.
3. Stale backup state appears on the dashboard in Arabic/RTL exactly when unsynced entries exceed 48h, and only then.
4. No `double` in any money path — evidenced in the verification report.
5. `RELEASES.md` exists; operations protocol appended; migration rule recorded.
6. All prior 159 tests + new tests green; analyzer clean; CI green; release-mode runtime pass recorded.
7. Zero changes under `supabase/`.

## 14. Builder AI Instructions

**DO:**
- Run Phase 0 completely before editing any file; record evidence.
- Keep staleness logic pure and in the core/sync layer; UI consumes state only.
- Route every cross-feature access through barrels.
- Add l10n strings through `intl` with Arabic as primary.
- Follow the stop conditions literally.

**DON'T:**
- Don't add plugins, platform channels, or any Android-specific API.
- Don't add routes, hub tiles, or product features.
- Don't touch `LedgerEntryType.wireName` or the ledger's append-only invariant.
- Don't edit migrations `0001`/`0002` or their drift equivalents in place.
- Don't persist anything that can be derived.
- Don't clear or mutate Plan 09's error-count behavior.
- Don't make the stale dialog destructive (no "reset", no "delete").

**Common mistakes:**
- Computing staleness inside the widget.
- Introducing a new timer instead of hooking existing scheduler ticks.
- Forgetting the empty-ledger case (false alarm on fresh installs).
- Logging ledger values into the new error/dialog paths.
- Fixing a V1 stop-condition inline instead of escalating.

## 15. Definition of Done

- All acceptance criteria met and evidenced in the PR.
- `FEATURES.md` shipped-entry written with test counts and runtime evidence; `PROJECT_MEMORY.md` and `DECISIONS.md` updated; migration rule live in `AGENTS.md`.
- CI green including release APK build.
- Staff Engineer sign-off recorded on the Phase 0 report before merge.