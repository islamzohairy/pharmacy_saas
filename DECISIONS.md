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

## 2026-08-02 — Android applicationId: com.skypiecode.pharmacy_saas
DECISION: `applicationId`/`namespace` = `com.skypiecode.pharmacy_saas`
(org identifier `com.skypiecode`, per the owner's Play Store identity).
Applied across android/, ios/, and macos/ bundle identifiers.
WHY: the package name is load-bearing for signing, Play Store identity,
and future Firebase config — cheapest to fix before first release, not
after.
ALTERNATIVES CONSIDERED: keeping `com.example.pharmacy_saas` (rejected —
placeholder namespace, not shippable).

## 2026-08-02 — Encryption mechanism: sqlite3 3.x hooks + SQLCipher build
DECISION: local database encryption at rest is configured via the pubspec
hooks user-define (`hooks: user_defines: sqlite3: source: sqlcipher`),
which makes `package:sqlite3` 3.x bundle the SQLCipher-compiled library.
The `sqlcipher_flutter_libs` package was **not** added — it is a no-op
since sqlite3 3.x moved to the hooks mechanism.
WHY: `SECURITY.md` requires the drift DB encrypted at rest; the hooks
user-define is the current (and only functional) way to get SQLCipher
under drift 2.34 / sqlite3 3.5. The DB key is a random 256-bit value
stored in `flutter_secure_storage` (`db_key_v1`), never in the DB file.
License check per `GLOBAL_RULES.md`: SQLCipher community build is
BSD-style licensed and links OpenSSL on some platforms (Apache-2.0) —
acceptable for a commercial app, recorded here as the governance check.
ALTERNATIVES CONSIDERED: `sqlcipher_flutter_libs` (obsolete, 0.7.0+eol is
a no-op); SQLite3MultipleCiphers (`source: sqlite3mc`, web-compatible but
SQLCipher is the mechanism the plan documents and works on Android).

## 2026-08-02 — Dependency governance check for foundation packages
DECISION: added `go_router` 17.x, `flutter_riverpod` 2.x, `intl`
0.20.2 (pinned by `flutter_localizations`), `supabase_flutter` 2.16,
`drift` 2.34.3 + `drift_flutter` 0.3.1, `flutter_secure_storage` 10.3.1,
`path_provider`, `path` (runtime); `drift_dev`, `build_runner` (dev).
WHY (check results): all are actively maintained (commits within the last
months), MIT/BSD/Apache licensed, and each maps to an already-decided
architecture item (`ARCHITECTURE.md` / `DECISIONS.md`) — none added "just
in case". `flutter_riverpod` stays on 2.x (hand-written providers, the
portfolio default); no codegen.
ALTERNATIVES CONSIDERED: none — packages were already mandated by
existing decisions; this entry records the governance check itself.

## 2026-08-02 — Cross-feature tables live in core, not in the feature
DECISION: drift tables (`Pharmacies`, `UserProfiles`) live in
`lib/core/data/tables/`, not inside `features/identity/data/` as the plan
drafted. Feature folders keep their repository/domain/presentation layers;
shared data tables are a core-layer concern.
WHY: `PLANS/03_DATA_AND_SYNC_PLAN.md` (ledger, customers, suppliers,
products) needs every feature to read/write the same tables — table
ownership by one feature would force cross-feature imports of another
feature's internals, which `ARCHITECTURE.md` forbids. The first plan
already set the precedent (plan 01 put `AppDatabase` in core).
ALTERNATIVES CONSIDERED: tables inside `features/identity/data/` (rejected
— violates the no-cross-feature-imports rule the moment plan 03 lands).

## 2026-08-02 — PIN: salted hash in secure storage, key reference in DB
DECISION: profile PINs are stored as a salted SHA-256 hash
(`salt:hash`, base64) in `flutter_secure_storage` under
`pin_hash_<profileId>`; the drift `UserProfile` row stores only the
storage key in `pin_hash_ref` (NULL = no PIN). Verifying compares the
salted hash, never the plaintext. Forgot-PIN = `wipeLocalIdentity` +
re-onboarding; the destructive, no-recovery consequence is stated in-app
before confirmation. Last-active profile id is persisted in secure storage
(`last_active_profile_id`) so the app restores the right profile after
restart.
WHY: PINs are device-local convenience credentials, not server secrets —
storage in secure storage keeps them off the encrypted DB (which is
copyable/restorable), and the hash keeps them out of the DB entirely.
SHA-256 over scrypt/argon2 is a deliberate trade: PINs have 10k possible
values so KDF strength buys nothing against offline attacks; the threat
here is shoulder-surfing / casual access, addressed by keeping material
in the OS keystore. There is no PIN-recovery path by design — a lost PIN
on a device with an encrypted-at-rest DB cannot be recovered by anyone,
so the only honest option is a reset, and the UI states it.
ALTERNATIVES CONSIDERED: scrypt/argon2 KDF (rejected — no added security
for a 4-digit space, added dependency); server-side account+reset flow
(rejected by the no-backend-auth decision above); biometric fallback
(deferred — `SECURITY.md` lists it as a follow-up).

## 2026-08-02 — Profile switch navigates with go(), not pop()
DECISION: after switching the active profile, the switcher screen
navigates with `context.goNamed(AppRoutes.dashboard)` rather than
`context.pop()`.
WHY (lesson): `go_router`'s `go()` replaces the page stack below the
navigated location, so there is nothing to pop after
onboarding → dashboard → profiles — `context.pop()` throws `GoError:
nothing to pop` at runtime (caught by the widget tests). `go()` is
deterministic for this one-screen flow.
ALTERNATIVES CONSIDERED: `pop()` (broken, see above); `push()` (rejected
— keeps the switcher on the back stack, user can't go "back" past a
profile switch).
