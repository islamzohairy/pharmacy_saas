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

## 2026-08-02 — Backup authentication: device token + SECURITY DEFINER RPC
DECISION: the P0 one-way ledger backup authenticates with a per-install
random 256-bit device token (base64url, stored in
`flutter_secure_storage` as `device_token_v1`) presented to two anon-
executable RPC functions, `register_device` and `push_ledger_entries`.
The server stores only the SHA-256 hex of the token in `devices`; the
tenant is derived server-side from the token hash — the payload never
carries a pharmacy id. Anon has ALL privileges revoked from every table
(no direct-table RLS policies), and the functions are SECURITY DEFINER.
Registration is register-first-wins on the pharmacy `uuid`: a uuid
already claimed by another token is refused.
WHY: RLS policies that key on the token require the token to be readable
inside the policy, forcing it into a table column (leakage if the table
is ever misgranted). The RPC layer keeps the hash-only column and gives
a single, auditable write surface. The anon key is extractable from the
APK by design, so every auth control lives server-side in the function
bodies; this model is the minimum that makes backup writes safe while
keeping P0 auth-free on the device. First-wins is chosen over last-wins
so an attacker who obtains a fresh token cannot hijack an already-
registered tenant (they could only create a new phantom tenant).
ALTERNATIVES CONSIDERED: anon upsert with RLS policies keyed on a stored
token (rejected — token must live in a readable column); server-side
accounts/session auth (rejected by the 2026-07-30 no-backend-auth
decision); per-request JWT signing (rejected — overkill while a single
token per install covers the threat: the token IS the possession factor).

## 2026-08-02 — Remote ledger PK is composite (pharmacy_id, id); retries are idempotent
DECISION: the server-side `ledger_entries` table uses
`primary key (pharmacy_id, id)` where `id` is the local drift
autoincrement, and `push_ledger_entries` inserts with
`ON CONFLICT (pharmacy_id, id) DO NOTHING`, returning the inserted
count. Local ids are 1,2,3… per install, so they collide across tenants;
the pair is what makes an idempotent retry safe.
WHY: the local-first sync design (plan 03) retries failed pushes with
backoff, and the app stamps `synced_at` only after the server acks.
Without the composite key, a retry after a partial network failure
silently duplicates money rows. With it, retries are a no-op by
construction (verified live: identical re-push returns 0).
ALTERNATIVES CONSIDERED: UUIDs per entry from the start (rejected —
deferred to the multi-device era; P0 is single-device so local
autoincrement is fine and cheaper); a server-returned upsert id (rejected
— adds a round trip per batch).

## 2026-08-02 — Sync scope is ledger-only in P0
DECISION: only `ledger_entries` is backed up. `products`, `suppliers`,
`customers`, and `user_profiles` exist on the server (schema parity) but
have no write path and no client code; their data is local-only in P0.
WHY: plan 03's problem statement is the data-loss risk for money
movement, which the ledger fully captures. Products/suppliers/customers
are re-entrable in a few hours each — their loss is a nuisance, not a
financial catastrophe — and extending sync to them multiplies the
conflict surface (hard delete, renames) that the single-device assumption
is meant to avoid. The schema keeps parity so the migration path to
fuller sync is additive.
ALTERNATIVES CONSIDERED: full-table sync in P0 (rejected — conflict
surface without multi-device need); products-only sync (rejected —
inconsistent split of "recoverable" vs "valuable" data).

## 2026-08-02 — Schema deviations from plan 03: is_active and remote_uuid
DECISION: two deliberate deviations from the plan's table sketches, both
documented in the migration: (1) `products.is_active` boolean (default
true, soft-delete) instead of hard delete; (2) `pharmacies.remote_uuid`
random UUIDv4 instead of a sequential server id as the registration key.
WHY: (1) plan 05's product management must never destroy ledger-visible
history — `ledger_entries.product_id` is a RESTRICT FK, and hard-deleting
a product the ledger references is impossible by construction; soft
delete is the natural way to retire a product without a ledger dead end.
(2) sequential ids are guessable across tenants; the uuid is the only
client-visible key to the server, so it must not be enumerable.
ALTERNATIVES CONSIDERED: hard delete + NULL-out ledger refs (rejected —
destroys attribution, contradicts append-only); sequential registration
id (rejected — enumeration risk on the registration surface).

## 2026-08-02 — Backup status surface: in-app indicator, not settings screen
DECISION: backup state (never/syncing/synced/error) renders as a small
indicator in the dashboard's bottom bar (`BackupStatusIndicator`,
Arabic labels, synced time shown) fed by a ChangeNotifierProvider
(`backupStatusProvider`). No settings screen in P0.
WHY: the plan's requirement is that the owner can see backup is working
— the indicator addresses the trust concern with zero navigation cost.
The scheduler never throws (errors land in the status, not the UI).
ALTERNATIVES CONSIDERED: settings/backup screen (rejected — another
route to build and maintain for one boolean-ish signal in P0); toast on
failure (rejected — transient, disappears before the user can act).

## 2026-08-02 — Profit COGS is injected into calculateProfit, not stored in the ledger row
DECISION: `calculateProfit` (PLANS/04) takes an injected
`int? Function(int productId) costMinorOf` resolver and returns a
`ProfitBreakdown` (sales/cost/draws/net) instead of the plan's literal
`calculateProfit(entries, dateRange)` single-number signature. COGS for
each `sale` entry is read from the referenced product's `cost_minor` at
calculation time; a sale with no resolvable product cost counts as zero
cost.
WHY: the plan's literal signature is unimplementable as written —
`LedgerEntry` has no cost field, and plan 05 explicitly forbids
duplicating cost into the ledger row ("the ledger stores what happened,
not a derived number"). Injection keeps the calculator a pure function
over `List<LedgerEntry>` with no drift or products-feature import, which
is what the plan's own testability requirement demands. The breakdown
return type (not a single int) is what plan 07's dashboard actually
renders (sales total, cost total, draws total, net profit as separate
figures).
ALTERNATIVES CONSIDERED: storing COGS on the sale row (rejected —
contradicts plan 05's explicit design and would go stale on a product
cost change); resolving costs inside the calculator via a repository
import (rejected — breaks the no-drift-import rule the plan states as an
acceptance criterion).

## 2026-08-02 — Plan 04 attribution: caller-resolved profileId, barrel exports
DECISION: the plan-04 record use-cases take `int? profileId` (and
`pharmacyId`) as plain parameters resolved by the caller from
`activeProfileProvider` — not a `UserProfile` object and not the provider
itself. The ledger domain stays free of any provider/identity-feature
dependency. Additionally, the ledger feature barrel (`ledger.dart`) gained
exports for the use-cases and calculators, which the plan's "Modified:
none" section did not list.
WHY: the plan's literal wording ("taking validated input +
activeProfileProvider's current profile") would force ledger domain code
to import the identity feature — a direct no-cross-feature-imports
violation (ARCHITECTURE.md). Passing the id keeps the use-cases pure and
trivially testable; plan 06's screens resolve the active profile and pass
its `id`/`pharmacyId`. The barrel exports are the feature's public API —
screens must import through `ledger.dart` only, per the feature-first
rule.
ALTERNATIVES CONSIDERED: passing a `UserProfile` into the use-cases
(rejected — forces a ledger→identity import); reading providers inside
the use-case files (rejected — same violation, and breaks pure-function
testability).

## 2026-08-02 — Plan 05 money parsing: own helper, ar_EG pinned, reject >2 decimals
DECISION: plan 05's money entry goes through a new core helper
(`lib/core/format/money.dart`): `parseEgpToMinor` (Arabic/Western digits,
`.` or `٫` decimal, strips thousands separators/whitespace, `FormatException`
otherwise) and `formatEgp` (`NumberFormat('#,##0.00', 'ar_EG')` + ` ج.م`).
`ar_EG` is pinned explicitly, not `ar`.
WHY: `NumberFormat(..., 'ar')` resolves to Latin digits in any context
that hasn't run the app localization delegates (bare Dart, notification
strings) — `ar_EG` resolves to Arabic-Indic symbols everywhere. The parse
contract (no signs, no letters, max 2 decimals) makes money entry a typed
int at the form boundary, so the use-case layer still receives integer
minor units with zero float exposure. Rejecting >2 decimals (rather than
rounding) prevents a silently wrong amount.
ALTERNATIVES CONSIDERED: letting `TextInputType.number` + `int.parse`
handle entry (rejected — Arabic-Indic keyboards produce `٠١٢٣…` which
`int.parse` rejects, and widget tests can't type them); a rounding parse
(rejected — silent money mutation).

## 2026-08-02 — Plan 05 recordSale: per-line appends, sellMinor from product
DECISION: `recordSale(repository, {pharmacyId, productId, quantity,
sellMinor, occurredAt, profileId, note})` writes exactly one append-only
`sale` row per call (`amountMinor = sellMinor × quantity`); the sales
screen loops the cart lines calling it once per line. `sellMinor` is the
product's price read from the catalog at entry time — the ledger stores
what happened, not a duplicated cost/price snapshot.
WHY: the plan's literal signature took `saleTotal` (whole-cart) which
cannot be expressed in the append-only ledger — a sale line must be one
row with its own `product_id` or profit attribution breaks (PLANS/04).
Per-line is also naturally non-atomic: each successful line is already
in the ledger if a later one fails, which is correct append-only
behaviour (the screen reports the failure; nothing is rolled back).
`product_id` on the row (a plan addition) is what `calculateProfit`'
s COGS injection resolves from (see the plan-04 profit decision).
ALTERNATIVES CONSIDERED: a whole-cart `saleTotal` single row (rejected —
loses per-product attribution); wrapping lines in a transaction (rejected
— no transaction path exists or is wanted in an append-only ledger).

## 2026-08-02 — Plan 05 scope extension: soft-deactivate, no inventory, no dashboard nav
DECISION: plan 05 ships with product soft-deactivation (hide + confirm
dialog, `is_active = 0`) even though the plan file did not list it;
there is no inventory/stock workflow, and the dashboard gets no
navigation to the new screens (sales/products are reached by their routes
only until plan 07).
WHY: without deactivate, an owner who mis-typed a product name or sells
items she no longer carries would have to keep it forever — the plan
itself blocks hard delete. Soft-deactivate is the smallest safe
complement (row retained, ledger refs stay valid). Inventory and
dashboard nav are deliberate plan-06/07 scope, not omissions.
ALTERNATIVES CONSIDERED: full delete (rejected — destroys ledger
attribution); an edit-only workaround (rejected — a renamed product
still shows in the picker); shipping nav now (rejected — plan 07 owns
the dashboard).

## 2026-08-02 — Plan 05 screens reach the providers through feature barrels
DECISION: the products feature barrel (`products.dart`) exports its
`presentation/products_providers.dart` (plan file listed "Modified: none"
for products); the ledger barrel (`ledger.dart`) exports
`presentation/ledger_providers.dart`; the sales screen imports
`ledger.dart` + `products.dart` + the identity barrel — never feature
internals. The product form routes via `pushNamed` (back stack), not
`goNamed`.
WHY: the sales screen needs the ledger repository (to append) and the
active catalog — the only legal paths are the barrels. The plan's own
"no cross-feature internal imports" rule makes the barrel export the
required mechanism even though the plan didn't list the file change.
`pushNamed` for the form gives Android back-button/back-gesture
behaviour; `goNamed` replaces the route, leaving nothing to pop.
ALTERNATIVES CONSIDERED: sales screen constructing
`DriftLedgerRepository` itself (rejected — duplicate wiring, provider
overrides in tests would not apply); `goNamed` for the form (rejected —
no back stack, save-then-pop throws).

## 2026-08-02 — Dependency: mcp_toolkit + flutter-mcp-toolkit (runtime-verification tooling)
DECISION: added `mcp_toolkit: ^3.0.0` as a runtime dependency; `main.dart`
boots the app through `MCPToolkitBinding.instance.bootstrapFlutter(...)`
(VM-service extensions registered in debug mode only, inert in release);
the `flutter-mcp-toolkit` binary (3.1.0, installed to `~/.local/bin`,
PATH entry added to `~/.zshrc`) is wired into this project's
`opencode.json` as the `flutter-mcp-toolkit` MCP server (`serve`
subcommand, absolute binary path). Governed per `GLOBAL_RULES.md`
dependency checks: MIT license, actively maintained (commits/releases
June 2026), verified publisher on pub.dev, maps to the already-decided
runtime-verification requirement in `DEFINITION_OF_DONE.md` /
`MCP_AND_TOOLING.md` — this is what lets plan 06's high-trust flows be
actually run and observed, not just unit-tested.
WHY: `DEFINITION_OF_DONE.md` requires runtime verification of critical
flows; the toolkit is the prescribed mechanism. The 3.1.0 stable release
is pinned deliberately over the 4.0.0-dev prerelease the installer
defaults to — the project's own README notice says to stay on stable 3.x
until 4.0.0 is promoted. Note: the tool's `codegen-init` fails on
current pub.dev (it tries `flutter pub add flutter_mcp_toolkit`, which
doesn't exist — the package is `mcp_toolkit`), so the integration was
done manually per the package's documented bootstrap. `init opencode`
does not exist in 3.1.0 (claude-code/cursor/codex/cline only), so the
MCP entry was written by hand.
ALTERNATIVES CONSIDERED: skipping the in-app package and using only the
binary's `fmt_*` tools (rejected — loses app-error forwarding and
dynamic-tool registration the OS docs prescribe); the 4.0.0-dev train
(rejected — prerelease, per upstream's own guidance).

## 2026-08-02 — Plan 06 deviation: presentation-only; the plan file's data-layer sections are stale
DECISION: Plan 06's "File Structure Impact"/data-layer sections predate
plans 03 and 04 — the supplier/customer repositories and the four ledger
use-cases they call for were already shipped there. The actual plan 06
work was therefore UI-only: three screens (draws, supplier debt, customer
debt) on the existing domain/data layers, plus presentation-layer balance
providers. Where `PLANS/06` contradicts the shipped code, the code is the
source of truth; the plan file is kept as-is for history.
WHY: per `AGENT_BEHAVIOR.md`, verify before writing; re-implementing
existing repositories would have duplicated plan 03/04 work.

## 2026-08-02 — Plan 06 delete edge case superseded: no delete in P0, soft-deactivation deferred, destructive deletion blocked
DECISION: PLANS/06's delete edge case ("a supplier/customer with ledger
history and a delete intent") is NOT implemented in P0, superseding the
earlier draft that would have shipped a confirm-and-delete path. No hard
delete exists anywhere in the UI; soft-deactivation (the only acceptable
alternative) requires an `is_active` schema change on
`suppliers`/`customers`, which is outside plan 06's UI-only scope and is
deferred to a later plan. Deletion is therefore blocked by construction:
no repository/use-case exposes it, no UI affordance exists, and ledger
history is preserved. (A ledger with the party reference would have made
deletion a history-corrupting operation anyway.)
WHY: preserves the append-only ledger and financial history; P0 has no
deletion problem to solve — plans 03/04/06 never added a delete path.

## 2026-08-02 — Plan 06 balance streams: presentation-layer merge, no new LedgerRepository API, no rxdart
DECISION: supplier/customer balances are computed by a presentation-layer
StreamProvider that merges three live streams — the party table
(`watchAll`) and two type-filtered ledger streams (`supplierDebt` +
`debtRepayment` / `customerDebt` + `debtRepayment`) — via a small
`combineLatest3` helper in `core/streams/combine_latest.dart` (emits
nothing until all three emit; cancels input subscriptions on cancel).
Sorted non-zero balances first (|balance| desc, then name). rxdart was
NOT added for this (checked the dependency tree; a hand-written
`combineLatest3` is ~40 lines and avoids a transitive-tree addition for
one merge).
WHY: `LedgerRepository.watchEntries` filters by a single party type, so
an owed amount needs both the debt and the repayment streams; keeping the
merge at the presentation layer avoids a new repository API for one
screen.

## 2026-08-02 — Plan 06 tests: full-app pump convention over the plan's "stub the use-cases" line
DECISION: plan 06's screens are tested with the project's established
full-app convention — `FakeSecureStore` + in-memory Drift DB +
`ProviderContainer` overrides + `buildRouter(initialLocation: ...)`,
seeding suppliers/customers/ledger rows via helpers
(`seedSupplier`, `seedCustomer`, `seedSupplierEntry`, `seedCustomerEntry`
in `test/support/helpers.dart`) — instead of the plan's suggested
use-case stubbing. The `combineLatest3` helper itself gets pure unit
tests. 17 new tests (draws 3, supplier debt 6, customer debt 5, streams
3).
WHY: matches the plan 05 convention the suite is already built around;
use-case stubbing would have created a second, weaker pattern and left
the screens' integration with the real repositories untested.

## 2026-08-03 — Plan 07 dashboard: single autoDispose StreamProvider + combineLatest3, no new repository API
DECISION: the dashboard reads everything it shows through one
`dashboardProvider` — an autoDispose StreamProvider that combines three
streams (`watchEntries(range)` for the profit card, `watchEntries(all)`
for the all-time debt totals, `watchAll(products)` for the COGS cost
resolver) via the existing `combineLatest3` helper from plan 06. Range
state is a tiny `StateProvider<DashboardRange>` defaulting to today;
`DashboardRange` + `rangeOf` live in the dashboard domain and are pure.
WHY: reuses the plan 06 presentation-merge pattern instead of inventing
a new repository API for one screen; autoDispose keeps the provider from
living on after navigation (the identity tests below are the reason this
matters at all).

## 2026-08-03 — Plan 07 debt card: totals are all-time, NOT range-scoped (user-confirmed deviation from plan text)
DECISION: the dashboard's supplier/customer balances card always shows
the all-time totals (owed to suppliers / owed by customers), regardless
of the selected range. The plan's suggested range-scoped wording was
confirmed with the user, who wanted a fixed, stable debt picture on the
dashboard; range scoping belongs to future reports. Implemented by
feeding `watchEntries(all)` into the balance totals while the profit
card uses the range-filtered stream. An overdue-debt callout is deferred
to plan 08+.
WHY: product-level correction before implementation, recorded so a
future session doesn't "fix" this back to range-scoped.

## 2026-08-03 — Plan 07 week range starts on Saturday (user-confirmed)
DECISION: "this week" on the dashboard runs Saturday→Friday (Egyptian
week), implemented as `DashboardRange.week` filtering `from` =
startOfWeek(weekday: DateTime.saturday) rather than Dart's
Monday-based `DateTime` convention. Unit-tested in `dashboard_range_test`.
WHY: the user's actual working week is Saturday-based; a Monday-based
week would split their week across two ranges.

## 2026-08-03 — Plan 07 COGS: per-sale-entry cost resolution, deactivated products still resolve (plan-04 line confirmed)
DECISION: profit cost is the sum of `products.cost_minor` resolved per
`sale` entry at calculation time (plan 04/05 semantics — cost is not
stored in the ledger row). Because an entry's product may be
deactivated since the sale, the products stream feeds `watchAll`
(including deactivated rows), not the active-only list; the repository's
new `watchAll` mirrors the existing per-pharmacy isolation. Deactivated
rows never appear in the products *screen* (unchanged), only in
cost resolution.
WHY: resolves deactivated-products COGS for history without changing
ledger schema; screen behavior unchanged.

## 2026-08-03 — lesson: drift + fake_async test hang — tests that navigate away from a drift-watching screen must flush close timers
LESSON: `identity_flow_test`'s forgot-PIN case started hanging
("did not complete") only after plan 07 landed, because the onboarding
creation flow now lands on the real `DashboardScreen`: navigating away
mid-test disposes its autoDispose drift-watch providers, and
`StreamQueryStore.close()` awaits drift-close timers (scheduled via
`markAsClosed`) that never fire while the zone's fake timers are
suspended — flutter_tester wedges. Bisect-proven (git worktree at
plan-06 HEAD passes in ~2s; adding the dashboard feature reproduces the
hang) — it was NOT a pre-existing flake. Fix: shared
`unmountAndFlushDriftTimers(WidgetTester)` in `test/support/helpers.dart`
— pumps an empty widget and interleaves `tester.runAsync` (real-async
progress) with short pumps (fake-zone elapse) ~10 times, forcing the
cancel chain to complete. Used by both the identity forgot-PIN test and
the dashboard nav tests. Any new test that starts on a drift-watching
screen and then navigates away must end with this call.
WHY: recorded so the failure mode (hang, "did not complete", 10-minute
suite) is recognized instantly instead of re-diagnosed.

## 2026-08-03 — Plan 07 known edge (reviewer note, deferred): dashboard left open across midnight keeps the prior "today"
NOTE: `rangeOf(..., DateTime.now())` is captured at provider rebuild, so a
dashboard left open across midnight keeps showing the previous "today"
until any ledger/range/profile change triggers a rebuild. Consistent with
the "recompute on change" design; the home screen is typically not left
open overnight. If a midnight rollover is wanted, that's a plan 08
decision, not a plan 07 fix.

## 2026-08-03 — Working rule: plan-first discovery triage (user directive)
DECISION: added a "Discovery and scope control" section to this project's
`AGENTS.md` (user directive, applies to every plan here): follow the
existing plan instructions first — no scope expansion or direction change
based on discoveries without reporting and confirmation. Findings triage:
required by the existing plan/DoD → proceed and document the reason here;
changes scope, architecture, or previous decisions → stop and ask first;
every deviation stays recorded in `DECISIONS.md`.
WHY: the user chose project scope over CORE_SYSTEM — the rule depends on
this project's PLANS/DECISIONS/FEATURES workflow and should not affect
unrelated projects. CORE_SYSTEM deliberately unchanged.

## 2026-08-03 — Plan 08 CI: workflow creation classified as plan-required; plan 01's CI claim corrected (user-directed triage)
DECISION: `.github/workflows/ci.yaml` (analyze + full test suite +
`flutter build apk --release` gate) is created under plan 08. Per the
AGENTS.md discovery rule, this is classified as REQUIRED by the existing
plan — PLANS/08 acceptance criterion 1 ("full test suite passes in CI,
including on a release build") — not a new feature. The plan's File
Structure Impact said "CI config (plan 01) extended", but plan 01 never
shipped a workflow (no `.github/` exists anywhere; FEATURES.md's plan-01
"CI analyze+test on push" claim was a documentation mismatch) — the
precondition is false, so "extend" becomes "create": a mechanism-level
deviation with the same gate. FEATURES.md's plan-01 bullet corrected in
place (current-state file, per MEMORY_RULES). CI builds with the
template's debug-signing fallback — no signing secrets ever reach CI
(user-confirmed); signed pilot APKs are produced locally via gitignored
`key.properties`.

## 2026-08-03 — Crash reporting deferred to post-pilot (user decision)
DECISION: no crash-reporting SDK ships with the P0 pilot APK. Pilots
follow the manual reporting path in `SUPPORT_AND_ROLLBACK.md` §1 and §4
(describe action + screenshot; release builds log via `adb logcat -d` /
bug report if the device is reachable). A proper SDK (Crashlytics or
equivalent) is evaluated post-pilot with the dependency-governance check
from `GLOBAL_RULES.md`.
WHY: single-owner pilot with in-person support makes an SDK's marginal
value low now; it would add a dependency and build tooling to the pilot
cut for a monitoring need that post-pilot scale actually justifies.
Deferred, not cancelled — recorded so it isn't relitigated at every
release.

## 2026-08-03 — P0 shipped: plan 08 complete (signing runbook + rollback doc)
DECISION: plan 08 (pilot release gate) is complete. Release signing uses
a conditional `android/app/build.gradle.kts` config: `rootProject.file(
"key.properties")` (→ `android/key.properties`, gitignored) — when
present, the release buildType signs with it; when absent (repo/CI/dev),
it falls back to debug signing so CI and local `flutter build apk
--release` stay secret-free. No keystore exists yet — the user generates
one locally via the runbook in `SUPPORT_AND_ROLLBACK.md` §3 before
distributing to the pilot device (a present-but-incomplete
`key.properties` fails loudly at configuration time, per the
security-agent review — no silent downgrade to debug signing).
`SUPPORT_AND_ROLLBACK.md` adds pilot support (§1) and version-tagged APK
rollback (§2) with the signature-mismatch landmine documented twice
(§2, §3): a debug-signed build and a keystore-signed build cannot
replace each other in place — uninstalling wipes local data.
WHY: closes the pilot-readiness gate; all eight P0 plans (01–08) are
now shipped. Deliberately deferred (not P0): crash reporting
(entry above), employee enforcement and expiry alerting (gated on
interview/ICP-B confirmation, see FEATURES.md roadmap), e-invoicing
(gated on `COMPLIANCE.md` `confirmed-by-counsel`).

## 2026-08-03 — Known edge (user-reported, deferred): hub navigation has no back stack
NOTED: every hub tile and dashboard/sales CTA uses `context.goNamed(...)`
(dashboard_screen.dart:208 hub, :246 empty-state CTA;
sales_screen.dart:129) — go_router `go` replaces the location, so there
is no previous entry to pop to; system back and the AppBar back arrow
(only auto-shown when a route can pop) exit the app instead of returning
to the dashboard. Only the product form uses `pushNamed` (pops
correctly); onboarding→dashboard and profile-switcher transitions are
deliberate replacement flows. User reported this on the pilot-ready
build (2026-08-03).
DECISION: deferred, not fixed now — recorded as a candidate for the next
plan. Fix direction already scoped: switch the hub tile + dashboard/
sales CTAs to `context.pushNamed` (every target screen already has a
plain AppBar, so Flutter auto-adds the RTL-correct back arrow; no
per-screen edits needed), keep `goNamed` for the replacement flows
above, add a nav-hub back-navigation widget test. Tracked in
`FEATURES.md` "Known issues (deferred)".
WHY: user opted to park it for review in the next plan rather than
expand the closed-out plan 08. Recorded so a future session recognizes
the cause instantly and doesn't relitigate the go() vs push() choice.

## 2026-08-03 — Back navigation implemented (supersedes the entry above)
DECISION: the deferred back-navigation fix shipped with plan 09, per the
staff-engineer review priority: hub tiles and dashboard/sales CTAs now
use `context.pushNamed` (dashboard_screen.dart hub + empty-state CTA,
sales_screen.dart products CTA). `goNamed` remains ONLY for replacement
flows: onboarding→dashboard, the dashboard AppBar profile entry, profile
selection, and wipe→onboarding. Added back-nav widget tests (tap
`BackButton` by type — `tester.pageBack()` only matches the English
'Back' tooltip and fails under Arabic localization). Two notes worth
keeping: (1) with push, the dashboard stays mounted beneath pushed
routes, so its drift-watch providers are NOT disposed on navigation — the
fake_async close-timer helper calls in hub tests are now conservative
no-ops, and (2) `AsyncValue.value` rethrows in error state — the
indicator reads `valueOrNull` so a missing-DB test render is a quiet
no-op, never a thrown build.
WHY: closes the user-reported symptom (back exits the app instead of
returning to the dashboard) with the standard push model.

## 2026-08-03 — Plan 09: local crash visibility (staff-review follow-up)
DECISION: no crash-reporting SDK; instead a LOCAL error log —
`runZonedGuarded` + chained `FlutterError.onError` and
`PlatformDispatcher.instance.onError` handlers writing to a new
append-only drift table (`error_log_entries`, schema v4, SQLCipher-
encrypted like everything else), surfaced by `ErrorLogIndicator` on the
dashboard bottom bar: unreported count (hidden at zero), tap → dialog →
"نسخ التقرير" copies a plain-text report (timestamp/type/message/
truncated stack) to the clipboard via Flutter's core `Clipboard` — zero
new dependencies — and "تم التبليغ" marks entries reported. The count is
cleared ONLY by that explicit action; opening the dashboard never
swallows a crash. LOCAL-ONLY by decision: diagnostics never ride the
ledger sync surface (no new RPC; like products/suppliers/customers).
WHY: the reviewer's real gap was "the only signal path is a non-technical
owner noticing and mentioning it"; a local artifact turns invisible into
visible-with-evidence at near-zero cost. Crashlytics (or equivalent)
would make reporting automatic rather than visible but needs a new
Firebase project, a governance-checked dependency, and a network path —
against this app's local-first posture — for one pilot device; REVISIT
the SDK decision when pilot count moves past one device, not before.
Also fixed under plan 09: `ARCHITECTURE.md`'s Remote/Authorization
paragraph (it still described "Supabase Auth + RLS scoped to
pharmacy_id"; reality is deny-all + two SECURITY DEFINER functions +
device-token model — now matches `SECURITY.md`) and `.flutter_mcp/`
hygiene (tracked binary cache removed via `git rm --cached`,
`.flutter_mcp/` gitignored).

## 2026-08-03 — Bug fix: MCP startup zone mismatch (surfaced by plan 09's capture)
DECISION: replaced `MCPToolkitBinding.instance.bootstrapFlutter(...)` in
`main.dart` with the package's documented pattern — `..initialize()
..initializeFlutterToolkit()` followed directly by `runApp` — inside the
existing single `runZonedGuarded` zone; the zone handler now chains
`MCPToolkitBinding.instance.handleZoneError` before `reportZoneErrors`.
`error_log_capture.dart` is untouched (install order unchanged, so the
`FlutterError.onError` chain stays MCP → our log → original).
WHY: `bootstrapFlutter` creates its OWN `runZonedGuarded` zone and calls
`runApp` inside it; the binding's init zone is recorded at
`ensureInitialized`, so `runApp`'s debug-only `debugCheckZone('runApp')`
assert reported "Zone mismatch" every debug launch (verified pre-existing:
`git show 0e619a6:lib/main.dart` booted through `bootstrapFlutter` with no
wrapper, binding in the root zone — console-only noise plan 09's capture
made visible). Root cause is MCP behavior, not the plan-09 wrapper — the
wrapper only changed which zone the binding initialized in, never matching
bootstrap's inner zone. Release was never affected (assert stripped), which
is why plan-09's release runtime check was clean. Fix keeps all startup
steps, order, and both capture layers identical; debug now records app-
runtime zone escapes in our log too (previously they went to MCP's monitor
only, since the app ran in bootstrap's zone). API verified against pinned
mcp_toolkit 3.0.0 source before the change: `initialize()`,
`initializeFlutterToolkit()` (extension; registers the same
`getFlutterMcpToolkitEntries` set bootstrap registered — confirmed by
"MCPToolkit Posted tool registration events: 18 tools" in the debug run),
and `handleZoneError` all exist with the assumed signatures.
VERIFIED: analyzer clean; 142/142 tests; release build (71.3MB) boots on
emulator-5554 with no FATAL; debug run on emulator-5554 shows no "Zone
mismatch" in logcat, all 18 MCP tools registered, on-device onboarding →
dashboard completes with the error indicator absent (fresh data; the "1"
seen on a reused-data install was the pre-fix entry persisted in the
append-only log).
ROLLBACK: single `git revert` of the fix commit restores the previous
bootstrap. lesson: crash visibility working as designed — the first error
it surfaced was a real, pre-existing integration bug.

## 2026-08-03 — Dashboard stale on back from hub screens: live range boundary
DIAG: `dashboardProvider` captured `rangeOf(range, DateTime.now())` once at
  provider creation; since hub nav became pushNamed (earlier 2026-08-03 entry)
  the dashboard stays mounted beneath pushed routes and its autoDispose
  provider is NOT disposed, so entries written on a pushed screen fell outside
  the frozen `to` window and the dashboard showed stale figures on return.
  Masked whenever the range re-selected (rebuild captured a fresh `now`); only
  the no-state-change round trip surfaced it. lesson: don't freeze "now" into a
  reactive read — a stream built with a creation-time time boundary goes stale
  the moment an append passes it.
FIX: single all-time `watchEntries(pharmacyId:)` stream (same query shape the
  debt screens already run) + products via a new `combineLatest2` helper; the
  `(from, to)` window is recomputed from `DateTime.now()` inside `.map` per
  emission and applied in Dart. Drift re-emits on insert, so a row written
  while away lands in-window on return. Purely reactive — no timers, no
  manual refresh, no invalidation.
TRADEOFF — SQL-bounded streaming removed: a `watchEntries(from:,to:)` stream
  re-queries with its creation-time bound, so `to` cannot follow the ledger; a
  live `to` requires the filter in Dart. Accepted at P0 scale: the all-time
  query is still served by the `(pharmacy_id, occurred_at)` index's tenant
  prefix, and the in-memory O(rows) range filter per insert is expected to
  stay sub-ms at realistic single-owner pilot volume — to be verified and
  documented against real pilot data. Supersedes the PLANS/07 "bounded by the
  (pharmacy_id, occurred_at) index" note.
FUTURE if ledger volume ever grows past that: (1) pre-materialized period
  aggregates rebuildable from the append-only ledger; (2) a "now" clock
  stream that widens an SQL window at day/week boundaries (a stream, not a
  timer — deferred by choice); (3) partitioned tables. None are P0.
VERIFIED: 14/14 dashboard widget tests (three new regression tests red before
  the fix — sale/draw/week away-writes froze on return — green after); full
  suite + analyzer pass; regression timing behavior documented: drift stores
  `occurred_at` at unix-second precision, so writes in the same wall-clock
  second as provider creation slip inside a frozen `to` — tests wait a real
  1.1s before the away-write to keep the red reproducible.

## 2026-08-04 — Plan 10 Phase 0: ledger wire-format bug fix (shipped as PR #1)
`LedgerEntryType.wireName` (`core/data/tables/ledger_entry_type.dart`) returned
`name` — Dart's camelCase identifier (`cashDraw`, `supplierDebt`, ...) — while
the remote whitelist (`0001_pharmacy_schema.sql` CHECK + `push_ledger_entries`
validation) expects snake_case. Only `sale` matched either way, so ad hoc
testing couldn't catch it. Fixed with an explicit exhaustive `switch`
(`cashDraw` → `cash_draw`, `supplier_debt`, `customer_debt`, `debt_repayment`),
the same pattern the new `ExpenseCategory.wireName` uses, so the compiler forces
every future type to declare its wire form. No local data migration needed (local
storage was never wrong — only outgoing serialization); `synced_at`-stamped push
design self-heals the existing backlog. Regression test in
`ledger_entry_type_test.dart`. VERIFIED: 159 tests green, analyzer clean.

## 2026-08-04 — Plan 10 Phases 1–4: expenses feature, activity feed, compliance-prep settings
PLANS/10 (expenses, activity history, compliance-prep) restructuring:
- Phase 1 (schema v5): `cashDraw` enum member renamed to `expense`; new nullable
  `category` column on `ledger_entries` typed by new `ExpenseCategory` enum
  (ownerDraw/rent/utilities/supplies/other) with its own `wireName`; local
  migration backfills existing `cashDraw` rows to `expense`/`ownerDraw` (their
  only valid meaning — an app-level migration, not a ledger write, so the
  append-only rule governs the normal write surface only). `pharmacies` gained
  nullable `tax_registration_number` + `legal_business_name`.
- Phase 2: `draws` feature replaced by `expenses` — category picker (Owner Draw
  first/default — must not regress the old fast-logging property), amount,
  optional note, past-expenses list; hub tile + figure row renamed;
  dashboards `drawsMinor` → `expensesMinor` (profit net of EVERY expense, per
  PRODUCT_DIRECTION_FINAL.md §2, not just owner draws).
- Phase 3: activity feed — `watchEntries` gained optional `int? limit`
  (default null = unbounded, so dashboard aggregation is unaffected); new
  `activity` feature capped at 100 rows, resolving profile display names via
  `getProfiles()`; 6th hub tile.
- Phase 4: settings screen (`/settings`, dashboard AppBar icon — NOT a 7th hub
  tile, low-frequency) capturing the two pharmacy fields via new
  `updatePharmacySettings` (first update-after-onboarding path for the Pharmacy
  entity). `COMPLIANCE.md` notes these are inert data capture and do NOT change
  the e-invoicing item's `unconfirmed` status.
DEPLOY GATE — CLEARED 2026-08-04 (user-confirmed): `supabase/migrations/
0002_expense_category.sql` applied to the live project and `rls_isolation_test.sql`
re-run green, so any build that pushes `'expense'` wire rows is safe. The migration
drops/recreates the anonymous `ledger_entries_type_check` so `expense` is admitted
while keeping historical `cash_draw` rows valid; category CHECK adheres to the
wire names. Phase 0 (`cash_draw`) is safe against the unmodified remote schema.
VERIFIED: 159 unit/widget tests green, analyzer clean; live e2e
(`test_live/rls_isolation_test.dart`) passed against the live project. Backfill
verified via raw-seeded fixtures only — no real pilot DB copy was available for
migration testing.

## 2026-08-05 — Plan 11 Phase 0 verification report (sign-off gate)
DECISION: Phase 0 (PLANS/11 §4.1) concluded with findings below; staff sign-off
recorded 2026-08-05 (user, via session approval). Implementation proceeds per
plan §7. No stop conditions triggered (no data destruction, no `double` in
money, no material scheduler divergence).
- V1 — DB-open/migration failure path: FAIL on error surfacing, PASS on
  non-destruction. `openAppDatabase()` is unguarded and drift opens lazily, so a
  corrupt file / SQLCipher key mismatch / throwing `onUpgrade` surfaces at the
  first query (`hasAnyProfile()` in `main.dart`) — `_startup` aborts, the zone
  guard's `reportZoneErrors` is a no-op (capture installs after open), nothing
  renders. Structural grep: no `File.delete`/recreate path for the DB anywhere;
  the forgot-PIN wipe deletes rows + secure-store keys only, never the file.
  → Hardening (plan §4.3) required.
- V2 — money types: PASS. Only `double` token in `lib/` is a layout width
  (`error_log_indicator.dart:65`); `formatEgp`'s `/100` is display-only inside
  `NumberFormat`; parse is pure int; remote wire `amount_minor` is int.
- V3 — scheduler wiring: PASS with one minor divergence. All four triggers
  match docs (start + 60s periodic, foreground resume, 5s write-debounce,
  5s→5min backoff); `SyncJob` never throws. Divergence: `SyncScheduler._run()`
  doesn't catch non-`StateError` identity-layer throws — they escape to
  `FlutterError.onError` and land in the error log (installed by then); app
  does not brick. Fixed in-phase (catch → `reportZoneErrors`).
- V4 — `watchEntries(limit:)`: PASS. `limit` used only by the activity feed
  (`activity_providers.dart:27`); dashboard/debt/expense reads unbounded.
- V5 — ledger query paths: PASS. Unsynced tracking IS a derivable signal
  (per-row `synced_at IS NULL` + `watchUnsyncedCount`); all queries bounded by
  the `(pharmacy_id, occurred_at)` index's tenant prefix. No
  `(pharmacy_id, synced_at)` composite index — per-tenant scan provably small
  at pilot volume; candidate only if volume grows (not P0, no schema change).

## 2026-08-05 — Plan 11: backup staleness is derived, no sync_metadata table
DECISION: backup staleness is DERIVED from existing sync state — unsynced count
(`watchUnsyncedCount`, already streams) + oldest unsynced `occurred_at`
(new one-shot bounded query, `ORDER BY occurred_at ASC LIMIT 1` on the same
`synced_at IS NULL` predicate) evaluated against a 48h threshold by one pure
function (`evaluateBackupStaleness` in `core/data/sync/backup_staleness.dart`).
Evaluated only on existing scheduler state changes (write-debounce / sync-pass
completion) — no new timer, no new stream. ZERO schema change; the
`sync_metadata` fallback table (plan §4.2 preference 2) is NOT needed.
WHY: Phase 0 V5 confirmed the derivable signal exists (per-row `synced_at IS
NULL` flag), so plan preference #1 applies — deriving beats persisting, and a
new table + migration v6 would add risk with no benefit.
THRESHOLD: 48h. Daily-use pilot; two missed days is already a support
conversation, and the backoff cap is 5 minutes so a healthy-but-offline device
never sits near the bound.
EDGE (clock manipulation): staleness compares entry timestamps against
`DateTime.now()`; a clock set backward masks staleness (negative age → pending)
— accepted residual risk for pilot, per plan §10.
EMPTY LEDGER: unsynced count 0 → healthy — a fresh install never alarms.

## 2026-08-05 — Plan 11 complete: implementation + runtime verification (closure)
DECISION: plan 11 shipped per §7 with zero schema change (schemaVersion stays 5,
no migration; remote `supabase/` untouched — no deploy gate needed this release).
179 unit/widget tests green (+20 over the 159 baseline), analyzer clean, release
APK builds (72.0MB; runtime build 74.1MB with the `.env.local` defines).
Runtime-verified on the emulator (release-mode, fresh install): onboarding →
dashboard; product create (Arabic-Indic price rendering); sale → dashboard
aggregation live-updates (sales 15.00, COGS 10.00, net 5.00, expenses 0.00);
backup indicator ERROR state non-destructive ("تعذر النسخ الاحتياطي — سنحاول
مرة أخرى" — app fully functional); cold restart → data persisted, no fatal
screen, no re-onboarding. Fatal-screen + stale states NOT runtime-reproducible
on this environment: the emulator image is a production build (no `adb root`)
and ignores `-qemu -rtc base=` (RTC skew), so a corrupt-DB or >48h-old unsynced
entry can't be staged on-device; both paths are covered by
`database_open_test.dart` (byte-identical file survival on corrupt file AND
throwing `onUpgrade`) and `backup_staleness_test.dart` (7 cases incl.
threshold-boundary) + indicator widget tests — stated honestly per DoD, not
claimed runtime-verified.
FINDING (config, not code): the local `.env.local` anon key returns 401 against
project `vhzvvveikzmuzxzrgbsr.supabase.co` (live-checked via REST). Expected
runtime effect: local dev builds show the backup error indicator because sync
always fails; pilot/dev sync is broken until the key is regenerated in the
Supabase dashboard and `.env.local` updated. Plan 11's error surface made this
visible — by design.

## 2026-08-05 — CORRECTION + root cause of the backup failure: remote FK bug, key is valid
CORRECTION (supersedes the FINDING in the closure entry above): the `.env.local`
anon key is VALID for project `vhzvvveikzmuzxzrgbsr`. Byte-level APK proof:
`app-release.apk` (built with `--dart-define-from-file=.env.local`) embeds the
identical URL and the identical 208-char key (sha256 `7435f72c…` == file's). The
earlier "401 = invalid key" reading was WRONG: that 401 was
`{"code":"42501","message":"permission denied for table ledger_entries"}` —
PostgREST's RLS denial for anon DIRECT table access, which is by design (anon is
locked to the two SECURITY DEFINER RPCs). No key rotation was performed and none
is needed.
ACTUAL ROOT CAUSE (verified live, 2026-08-05): the exact requests the app sends
succeed on the key and fail on the DATA:
- `POST /rest/v1/rpc/register_device` (exact app headers `apikey`+`Bearer`+app
  body) → HTTP 200.
- `POST /rest/v1/rpc/push_ledger_entries` with the app's exact
  `RemoteLedgerEntry.toJson()` payload → HTTP 409
  `{"code":"23503","details":"Key (profile_id)=(1) is not present in table
  \"user_profiles\"","message":"insert or update on table \"ledger_entries\"
  violates foreign key constraint \"ledger_entries_profile_id_fkey\"}`; the same
  with `product_id` → 409 `ledger_entries_product_id_fkey` on `products`.
- Identical payload with NO party ids → HTTP 200 (entry inserted).
WHY: `ledger_entries` (0001) FK-constrains `product_id/supplier_id/customer_id/
profile_id` against remote `products/suppliers/customers/user_profiles` — tables
that are NEVER populated because P0 sync scope is ledger-only (DECISIONS.md
2026-08-02). Every real app entry carries `profile_id` (and `product_id` on
sales), so EVERY real push 409s. The 2026-08-04 deploy-gate e2e passed because
its test payloads omit party ids — the gate verified RLS isolation, not the
app's real wire payload. The 401/409 responses are captured in the session
record; probe rows (pharmacy `verify-probe-uuid`, device, ledger id 900003)
were left on the dev project, pending user decision on cleanup.
DECISION: this is a REMOTE SCHEMA bug, not a client bug — the client's payload
matches the documented wire contract. Fix requires a NEW additive remote
migration (0003) + deploy gate; NOT implemented — reported and awaiting
user direction (AGENTS.md discovery rule: schema/architecture impact → stop
and ask). Candidate fix (recommended): drop the four `ledger_entries` FKs on
never-populated tables (0003), keeping the `type` CHECK and everything else;
client unchanged.

## 2026-08-05 — Plan 11-H executed: remote FK fix (migration 0003) + gate upgrade + cleanup (staff-engineer approved)
EVIDENCE CHAIN (each step verified live against the pilot project):
1. **On-device root-cause confirmation:** instrumented the installed app's
   sync path (temporary debugPrint, reverted after diagnosis) — the app's
   real payload 409s with `PostgrestException 23503: Key (product_id)=(1)
   is not present in table "products"` (`ledger_entries_product_id_fkey`),
   the same FK class as the earlier profile_id probe. Client payload
   matches the documented wire contract; this is a remote-schema bug.
2. **Migration 0003** (`supabase/migrations/0003_ledger_party_reference_fks.sql`)
   — drops the four never-populated reference FKs (`profile_id`,
   `product_id`, `supplier_id`, `customer_id`); `pharmacy_id` FK, type
   CHECK, RLS, anon surface untouched. Columns stay; re-add path documented
   in the file (NOT VALID → VALIDATE in a NEW migration). **Applied to the
   live project** (2026-08-05); post-state verified: exactly one FK remains
   (`ledger_entries_pharmacy_id_fkey`).
3. **Deploy gate re-run, upgraded permanently:** `rls_isolation_test.sql`
   now (a) asserts the FK count on `ledger_entries` = 1 (post-0003
   assertion, not assumption), (b) pushes a REAL app payload (sale with
   `product_id` + `profile_id`, expense with `profile_id` + `category`)
   under a dedicated disposable tenant and asserts persisted VALUES, (c)
   self-cleans at script end — its own a/b/gate tenants AND `live-test-%`
   e2e residue (anon cannot delete; the SQL gate runs with owner privilege
   at the same deploy gate, so it is the cleanup vehicle for the whole
   gate). Result live: ALL CHECKS PASSED. The 08-02/08-04 gate runs proved
   RLS isolation only — never the app's wire payload (payloads omitted
   party ids); that gap is closed.
4. **test_live e2e** (client contract, incl. the real-shape push) green.
5. **Proof curl:** exact original failing payload (sale `product_id=1
   profile_id=1`) under a fresh disposable tenant → 200, 2 rows persisted.
6. **One-off cleanup executed (user-confirmed 2026-08-05)** — the residue
   inventory classified every live tenant (10 found, zero orphans): 4
   md5-32hex SQL-gate tenants (plans 03/10 gate runs), 3 `live-test-*`
   e2e tenants (today's e2e; the gate sweep ran before it), 2 of my
   disposable probe/proof tenants, 1 REAL (`PharmacyTest`, uuid
   ae1e4e62-8974-4fac-bee2-383d4d3424a0 — kept). SQL executed verbatim:
   ```sql
   begin;
   delete from public.ledger_entries where pharmacy_id in (5,6,9,10,13,20,21,22,23);
   delete from public.devices where pharmacy_id in (5,6,9,10,13,20,21,22,23);
   delete from public.pharmacies where id in (5,6,9,10,13,20,21,22,23);
   commit;
   ```
   (14 entries, 9 devices, 9 pharmacies; executed as a one-off via psql,
   never committed as a file.) Post-state: the live project holds exactly
   the real tenant (1 device, 2 ledger entries).
7. **On-device acceptance (release APK, real app):** chip before =
   "تعذر النسخ الاحتياطي — سنحاول مرة أخرى" (error); after 0003 + retry =
   "آخر نسخة: 5/8/2026 11:10" (synced); both sales stamped and present
   remotely under the app's tenant; staleness derived healthy (0
   unsynced); relaunch state correct.
DISCOVERED AND FIXED (indicator no-op bug, Plan 11 code): a sync pass with
nothing to push and the device already registered returned `SyncResult`
indistinguishable from "skipped", so the scheduler early-returned and the
chip lingered at "syncing" forever after relaunch once the backlog was
empty. Fix in `sync_scheduler.dart`: a skipped result from a configured
pass now derives the real last-sync time from stamped entries
(`LedgerRepository.lastSyncedAt` — new read of max `synced_at`, derived,
never stored, same philosophy as staleness) and shows "synced" with that
time; the register-only first pass keeps its original synced semantics.
Covered by 2 new scheduler tests; 181 tests green, analyzer clean. The
release APK was rebuilt with this fix (only code change since the last
release build).
COORDINATION ON RECORD (staff-review Q3/adjustment 4): repo-wide grep for
Supabase URL/host references finds exactly ONE concrete host in the whole
repo — `vhzvvveikzmuzxzrgbsr.supabase.co` (this DECISIONS.md entry); every
other reference is the generic define-name/placeholder. `.env*` = only
`.env.local`; CI workflow and Android configs contain no URL. Single live
project statement confirmed on record.
V5/v6 COORDINATION (staff-review adjustment 4): Plan 11 Phase 0 V5 outcome
on record — a derived unsynced signal EXISTS (oldestUnsyncedAt), so the
`sync_metadata` fallback table was NOT used and no V5 migration shipped.
`schemaVersion` 6 is therefore FREE for Plan 11-H Phase 2's
`sync_quarantine` table; no two additive migrations race. When Phase 2
lands, the v6 rehearsal record goes here per the AGENTS.md standing rule
(fixture v5→v6 integrity pass + emulator runtime migration; full
rehearsal-on-real-data rule activates at the first migration after pilot
devices hold real data).
PHASE 2 DEFERRED (user decision, pending Phase 1 sign-off): SyncJob
permanent-failure classification — set stays EXACTLY
{23514,23503,23502,22P02} → quarantine in a new local drift table
(`sync_quarantine`, schemaVersion 6, excluded from unsyncedEntries, one
error-log record per quarantine, no auto-release); 23505 → success;
everything else (incl. 401/403) → existing capped backoff. Staleness
remains the visibility for those.
23505 BOUNDARY SENTENCE (Phase 1 acceptance, 2026-08-05): unique-violation
(23505) on `push_ledger_entries` is an EXPECTED race under concurrent
device writers — it is absorbed inside the push boundary (counted as
success), and it is never a sync-failure signal, never quarantined, never
surfaced to the user; anything OUTSIDE that boundary (401/403/network)
is the failure class the staleness/backoff/error-log path owns.

## 2026-08-05 — Plan 11-H Phase 1 gate FAILED: root cause = provider self-watch self-disposal (fixed, staff-engineer approved)
ROOT CAUSE (proven live on emulator 5556, 2026-08-05): `syncSchedulerProvider`
did `ref.watch(backupStatusProvider)`. In Riverpod 2.6.1,
`ChangeNotifierProviderElement` calls `setState(notifier)` on EVERY
`notifyListeners()` (flutter_riverpod-2.6.1 base.dart:216), which marks all
dependents changed → `invalidateSelf` → `runOnDispose` → the scheduler's own
`ref.onDispose(scheduler.dispose)` ran. The scheduler's FIRST status write
(`status.update(syncing)` in every pass) therefore invalidated its own
provider 200ms into the first pass, canceling periodic timer, debounce
timer, retry timer and backlog subscription; with zero listeners on
`syncSchedulerProvider` the invalidation is never rebuilt — the provider
stays dead. That one mechanism explains EVERY symptom (start-once,
resume-once, timers never fire, subscription dead, chip stuck at syncing).
Bisection evidence: probe-app (no Riverpod) on the same AVD fired timers
exactly on schedule → environment exonerated; instrumentation showed
`periodic created` → 213ms later `scheduler dispose: canceling timers` →
adjacent probes reading `debounce active=false` while local timers fired —
only `dispose()` can cancel field-backed timers.
FIX (one word, `sync_providers.dart`): `status: ref.read(backupStatusProvider)`
inside `syncSchedulerProvider`. Notifier lifecycle unchanged (single owner
= the ChangeNotifierProvider element, disposed once at container teardown);
the chip (`backup_status_indicator`) still watches, unaffected. Split
provider variant REJECTED (risks use-after-dispose if the status provider
is ever invalidated; read variant keeps the owner unique). Regression test
in `sync_scheduler_test.dart` (ProviderContainer + fakes: after `start()` +
flushMicrotasks the container must serve the SAME scheduler instance, and
a new write must still debounce-push): verified RED on the old wiring,
GREEN on the fix.
RULE (new): NEVER `ref.watch` a provider that your own execution path
writes to — the notifier's `notifyListeners` invalidates you mid-pass and
`onDispose` runs; if nobody listens to you, the invalidation is never
rebuilt. If the value is only READ, use `ref.read`. (Riverpod 3 will block
`ref.read` inside provider bodies entirely — revisit wiring on upgrade,
recording this before then.)
LESSON (acceptance-path): the v5 rehearsal, the 08-04 deploy gate and the
v5 gate all PASSED while this bug shipped in v6 — because none of them
EXERCISED the write-triggered path (no sale, no pending write) that the
Plan 11-H Phase 1 gate now runs (sale → debounce → push; idle → periodic;
relaunch → resume). Acceptance evidence only means something when it
drives the REAL trigger path; the Phase 1 gate's three write triggers are
now load-bearing for every future release of this sync path.

## 2026-08-05 — RELEASE builds had no INTERNET permission (manifest bug, found during Phase 1 re-verify)
FINDING: the release APK could never sync — `android/app/src/main/
AndroidManifest.xml` is the untouched stock Flutter template; the INTERNET
permission exists ONLY in the debug/profile manifests. netd denies DNS to
apps without it, surfacing as `_ClientSocketException: Failed host lookup
(OS Error: No address associated with hostname, errno = 7)` — a socket
permission denial MASKED as a DNS failure. Chrome/ping on the same device
resolved fine; the app resolved nothing. Debug builds worked (INTERNET
merged); every release build since the app gained network code could not
resolve or connect at all. Discovered during the condition-3 release
re-verify (chip showed "تعذر النسخ الاحتياطي" while the SAME code on
debug pushed fine; the gated diag's full error text identified the DNS
failure; `dumpsys package` showed zero INTERNET for the release install).
FIX: added `<uses-permission android:name="android.permission.INTERNET"/>`
to the MAIN manifest (backup sync ships in release — load-bearing, not
dev-only). Verified: release `pushed=1 error=null` (first successful
release push ever, 2026-08-05 14:53), chip "آخر نسخة: 5/8/2026 14:54".
CORRECTION to the 11:10 acceptance record (2026-08-05 11-H entry): the
claim "on-device acceptance (release APK, real app)" cannot be reconciled
with this finding — a release build could not push until the INTERNET fix,
so the 11:10 error→synced chip transition and the remote stamps were
produced by a DEBUG build (the stamps themselves were independently
verified via owner-privilege SQL and stand; the BUILD label is what's in
doubt). Also explains the v5-era "stale 401" error-chip readings on
release installs: no network permission, not a key issue. OPEN QUESTION
for the user: reconcile the 11:10 record (which build ran on the
acceptance device).
DIAG ENHANCEMENT (same pass): `_diagErrorSummary` now prints the FULL
message for non-Postgrest errors only (socket/OS/TLS errors carry no
ledger content — the content rule still holds for Postgrest messages);
this is what surfaced the DNS denial. Kept, gated behind SYNC_DIAG.

## 2026-08-05 — FINAL: 11:10 acceptance record corrected (definitive, staff-engineer directed) + manifest-permission lesson
CORRECTION, DEFINITIVE (supersedes the "in doubt" framing in the
INTERNET-fix entry above): Plan 11-H Phase 1 acceptance (chip flips,
entries stamped) was verified on a DEBUG build. Release builds could not
sync due to missing INTERNET permission (fixed 14:53). First successful
release-mode sync was 14:53. The remote stamps at 11:10 are real; the
"release APK" build label in the record was wrong.
LESSON (manifest-permission verification): the "release" label on any
acceptance evidence must be verified by checking the artifact's manifest
permissions (e.g., `dumpsys package ... | grep INTERNET` on the install,
or inspecting the merged manifest), not just by which build mode was
selected when it was produced. A debug/profiled artifact can be mistaken
for a release artifact when only runtime behavior is observed — and
release-only defects (permission gaps, tree-shaken code) survive unseen
until a clean release build is exercised.

## 2026-08-05 — Plan 11-H CLOSED: cleanup verified, final live-project state
CLEANUP VERIFIED (human-executed, owner-privilege psql, 2026-08-05):
probe tenant 24 (uuid `probe-709A6FBC382F4225816EAF44699C9FB4`) deleted —
exactly 2 ledger_entries, 1 device, 1 pharmacy; landscape query after
cleanup shows exactly two tenants: 14 (`ae1e4e62-…`, REAL pilot tenant,
2 entries, untouched) and 25 (`9b2b5683-b21a-47ee-8d31-667c460aeeb1`,
5556 emulator test tenant, 9 entries — 5 pre-gate Phase A/B-era + 4 gate
— untouched, KEPT).
GATE EVIDENCE LOCATION (correcting the verification misread): the four
Phase 1 trigger-path pushes (14:32/14:34/14:38/14:54 local) physically
live in tenant 25 — the 5556 install registers against that tenant, not
against PharmacyTest. Tenant 25 DISPOSAL TRIGGER: emulator 5556
retirement; it is not to become untracked cruft.
TIMESTAMP AXIS (the exact confusion that produced the stale criterion):
the LOCAL Drift ledger stamps `synced_at` client-side AFTER a successful
push — that is the unsynced-tracking/quarantine axis; the REMOTE
`ledger_entries.synced_at` is NEVER written by `push_ledger_entries`
(0001 insert omits it; NULL on every row by design) — `occurred_at` is
the remote timestamp axis, and remote-push verification must use it.
LESSON: verification criteria must be derived from the ACTUAL
schema/column semantics and the device's ACTUAL registered tenant — not
carried forward from an earlier memo. Same family as the
manifest-permission lesson: check reality, not the assumption.

## 2026-08-13 — Plan 12 Phase 0 verification report + baseline (staff-engineer approved 2026-08-13)
DECISION: Phase 0 (PLANS/12 §4) concluded all six checks PASS; no stop
conditions triggered (schemaVersion == 6, no `double` in money/quantity
paths); staff sign-off recorded. Implementation proceeds per plan §6,
branch `feature/12-inventory-foundation`.
- V1 — schemaVersion == 6 (`sync_quarantine` from Plan 11-H Phase 2
  shipped), v7 is the next slot — PASS (`app_database.dart:50`).
- V2 — table registration pattern: core-owned tables in
  `lib/core/data/tables/`, drift list + onCreate + onUpgrade ladder in
  `app_database.dart:34–98` — PASS; the v6 rehearsal test's DROP-TABLE +
  `PRAGMA user_version` rollback is the fixture template to mirror.
- V3 — product form: create-vs-edit is `widget.product != null`;
  `parseEgpToMinor` (core/format/money.dart) is pure int; the only
  `double` in lib/ is a layout width. Digit normalization is INLINE in
  `parseEgpToMinor` — extractable into a shared helper (Step 4) — PASS
  with that note recorded.
- V4 — product list: `activeProductsProvider` StreamProvider +
  `combineLatest2` join (dashboard precedent) avoids N+1 — PASS.
- V5 — barrels: `products.dart`/`ledger.dart`/identity barrels confirmed;
  new `inventory.dart` barrel follows the same shape — PASS.
- V6 — sync layer early negative check: zero references to
  products/suppliers/customers in `lib/core/data/sync/` — PASS;
  post-implementation grep re-run at closure.
BASELINE (empirical, supersedes the written "181 at scheduler-fix
checkpoint" and confirms the plan's "199" claim): full suite =
**199/199 tests green**, `flutter analyze` clean, on main
@542a0e4. The 181 record was stale by the quarantine/migration tests
added after the scheduler fix. Every later count is measured, not
carried from a memo — the 11-H "verify reality" lesson, applied.
FINDINGS RECORDED (per staff review): the gen-l10n failure mode is
runtime-only (analyzer can't catch a missed run — Step 9 makes it
explicit); the emulator runtime pass depends on rebuilding the release
APK with `.env.local` defines (its acceptance build is not reusable
with app-data-preserving install); `normalizeDigits` extraction must be
behavior-preserving (zero money-test edits allowed, else STOP).

## 2026-08-13 — Plan 12 decisions D1–D5 (recorded verbatim from PLANS/12 §3)
D1 — Stock model: append-only `stock_movements` ledger; on-hand = live
aggregate. Movements are never updated or deleted; a correction is a new
offsetting movement (same rule as the financial ledger).
D2 — Activity feed: stock movements merge into the activity history in
Plan 13, not Plan 12. Plan 12's only movement type is `initial` (one per
product, low signal); Plan 13 is where movement volume begins. The pilot
build ships after Plan 14, so no user-visible gap exists.
D3 — Negative stock: allowed, displayed gracefully. On-hand may go
negative (selling before a restock is logged). Never clamp, never block a
sale — the recording loop is Tier-1 behavior and must not depend on
inventory state. Negative on-hand is displayed in a distinct visual state
with correct Arabic negative formatting (numeric form `-٢` chosen at
implementation for consistency with other numeric displays, per staff
review). Rationale consistent with the existing never-clamp precedent
(supplier overpayment shows as credit, `رصيد دائن`).
D4 — Units: plain integer units (no minor units, no fractions).
Fractional stock is a future evidence-gated decision.
D5 — Placement: `stock_movements` drift table lives in
`lib/core/data/tables/` (multiple features will read/write it — products
now, sales in Plan 13 — per the 2026-08-02 cross-feature-tables
precedent); domain/data/presentation live in a new `inventory` feature
consumed through its barrel.

## 2026-08-13 — Plan 12 migration rehearsal, FIXTURE leg: v6→v7 PASSED
REHEARSAL (AGENTS.md standing rule, second execution of the standard;
template kept consistent with the v5→v6 run): fixture DB seeded as a real
v6 install — 1 pharmacy, 1 profile, 1 product, 1 supplier, 1 customer, 6
ledger entries (all five types; expense with `rent` + `ownerDraw`
categories; 3 synced + 3 unsynced), 1 quarantine row — then the v7-only
table dropped and `user_version` rewound to 6; reopen ran the REAL
`onUpgrade(6 → 7)`. BEFORE: 6 ledger entries / 3 unsynced / 1
quarantine / 5 identity+catalog rows. AFTER: `user_version == 7`;
`stock_movements` exists and EMPTY; every pre-existing row intact (all
types/categories/amounts/synced flags byte-identical; unsynced count
still 3; quarantine row intact). Data source: fixture (real pilot data
rehearsal applies at the first post-pilot migration). Test:
`test/core/data/stock_movements_migration_test.dart`.

## 2026-08-13 — Plan 12 migration rehearsal, DEVICE leg (real pilot data): v6→v7 PASSED
REHEARSAL completed on the real acceptance install per the AGENTS.md
standing rule (fixture leg above + this device leg = the standard). Target:
Medium_Phone AVD (emulator-5556), the 11-H acceptance device — release
install (versionName 1.0.0), tenant 25 (DiagPharma), not debuggable.
Sequence: (1) before-state captured (UI hierarchy: dashboard sums ٥٫٠٠ /
١٥٫٠٠ / ١٠٫٠٠ for صافي/مبيعات/تكلفة on this-month view); (2) new release
APK (Plan 12 build, `--dart-define-from-file=.env.local`) installed with
`adb install -r` over the v6 install (data-preserving; signature matched);
(3) launch → `user_version` migrated 6→7 silently, dashboard loads with all
prior data intact (this-month view reproduces identical sums; the "today"
view showing zeros is the period filter, not data loss — confirmed by
switching periods); (4) sync: chip "آخر نسخة: 13/8/2026 10:14" on the new
build — the old installed build could never push (pre-INTERNET-fix, its
chip showed the failure banner); remote count for tenant 25 unchanged at 12
entries (nothing new to push — inventory movements are local-only by
design); (5) feature check: product "Aspirin" created with initial stock
100 → appears in list with "المخزون: ١٠٠" live; pre-existing product shows
"المخزون: ٠". Evidence: uiautomator dumps + logcat + remote psql counts.
Data source: REAL pilot device data. No rollback needed (no delete/update
path exists; failure mode would have been DB-open fatal screen, absent).

## 2026-08-13 — Pilot backend pause/delete incident + resume (user-confirmed)
FINDING: `vhzvvveikzmuzxzrgbsr.supabase.co` returned NXDOMAIN from host,
Google DNS, and the emulator (anon key JWT `ref` matched the URL — not a
typo). Consistent with Supabase free-tier pause→delete after ~7 days of
inactivity; last verified activity 2026-08-05 14:53. The device's backup
failure banner was the symptom. The user resumed the project from the
Supabase dashboard (option 1 per the project's stop-and-ask rule). POST-
RESUME: DNS resolves (Cloudflare), REST + anon key auth healthy (RLS
denies anon table access as designed — 42501 on direct select is expected),
direct DB host `db.<ref>.supabase.co` is IPv6-only (no route from this
host) → owner-privilege psql now runs via the IPv4 session pooler
(`aws-0-eu-west-1.pooler.supabase.com`, user `postgres.<ref>`;
DATABASE_PASSWORD from `.env.local`, region discovered by probing). Schema
verified post-resume: migration 0003 applied (FK count on ledger_entries =
1), `expense_categories` present. DEPLOY GATE: `rls_isolation_test.sql`
re-run GREEN (all 12 checks, self-cleaning, zero residue). NOTE: tenant 25
now holds 12 remote entries
(9 documented at the 11-H gate + 3 pushed by the 14:53 acceptance push).
LESSON: a paused/deleted backend degrades silently into a stale "آخر نسخة"
chip + failure banner; the gate suite is the restore-time health check.

## 2026-08-13 — Plan 12 review fix: tracked-vs-zero distinction (staff-engineer approved)
FINDING (code review of commit 05cdbd7): the joined on-hand provider flattened
the aggregate map's key-absence into a false zero (`onHandMap[product.id] ??
0`), so products with no movements rendered `المخزون: ٠` — indistinguishable
from genuinely tracked-and-zero. Two harms: (1) Plan 12 UX — a wall of false
zeros on untracked products reads as "out of stock" during pilot adoption;
(2) Plan 14 correctness — a low-stock/needs-attention signal keying off
on-hand would flag every untracked product as out of stock. Root cause is the
join layer, not the aggregate: `DriftStockRepository.watchAllOnHand` already
returns absence for movement-less products — the signal existed and was
discarded. DECISION (supersedes the plan's original "empty history → 0"
display default): absence in the on-hand map = "not tracked" (0 movements);
absence IS the signal. The joined provider yields `List<(Product, int?)>`
(null = not tracked); the product list renders a neutral "—" for untracked
rows (stable layout, language-neutral, no l10n string) and keeps the error
color for negatives. `reduceOnHand` is untouched (empty → 0 remains the pure
SUM rule over a product's movements — that is not the same fact as
tracked-vs-zero). `watchOnHand` (single-product) is deliberately not
distinguished — its only consumers today are tests and the Plan 13
adjustment UI; Plan 13 must inherit the absence signal instead of re-adding
`?? 0` (flagged for the Plan 13 header). Verified: 224 tests green, analyzer
clean, on-device products list shows "—" for the untracked Paracetamol row.

## 2026-08-13 — Sync verified end-to-end; earlier "stuck sync" diagnosis corrected
FOLLOW-UP to the 05cdbd7 verification: the emulator's sync appeared stuck
(chip stuck at 10:23, sales never appearing remotely), and a quarantine
(FK 23503) was suspected. Root cause was a WRONG-TENANT query: the emulator
is tenant pharmacy 14 "PharmacyTest" (device token hash ef97…, registered
2026-08-05 08:05 UTC), while the 12-entry ledger belongs to tenant 25
"DiagPharma" — a different device's data. VERIFIED WORKING end-to-end: a
sale recorded via the app UI (sales screen confirm) appeared in remote
`ledger_entries` pharmacy 14 (id=3, 5000 @ 08:27:56 UTC) within one sync
pass, chip advancing 10:23 → 11:27. Confirmed by design: RLS enabled with
ZERO table policies (anon's only surface is the two SECURITY DEFINER RPCs
per 0001); `ledger_entries` has NO FK on product_id (remote products table
empty = expected, products are local-only in P0). The stray 5000 sale dated
10:23 (created by an accidental sales-screen tap during earlier UI probing
at the fix-APK reinstall window) was never pushed and will not be — it is
absent from the unsynced set (not present in the same 11:27 pass's batch),
so it is either synced-marked or quarantined locally; no future remote
pollution. LESSON: when diagnosing sync from the remote, query by the
device's ACTUAL tenant (derivable from `devices.token_hash` →
`pharmacies.id`), not by the tenant with the most rows; and distinguish
"sync stuck" from "syncing to a different tenant" before suspecting
quarantine. One test sale (5000, pharmacy 14) remains in the remote ledger
as verification evidence.

## 2026-08-13 — Plan 13 Phase 0 gate passed (staff-engineer approved)
Phase 0 verification of PLANS/13, all six checks carried out read-only,
no stop conditions triggered; staff engineer approved with three
affirmations and three watch-items. Verbatim findings:

- V1: `schemaVersion` == 7 (Plan 12 slot); v8 is the next slot.
- V2 / D8 transaction finding: `recordSale` (sales_screen.dart:68 →
  record_sale.dart → LedgerRepository.append, ledger_repository_impl.dart:21)
  already wraps each append in its own `_db.transaction`, and
  DriftStockRepository.recordMovement runs a single insertReturning with no
  exposed executor. Both repositories hold private `_db`; no interface
  surfaces a transaction/executor, and the coordinator lives above the
  repositories (presentation layer, plan §5.2). SHARING ONE DRIFT
  TRANSACTION ACROSS BOTH WRITES IS NOT ACHIEVABLE without restructuring
  repository interfaces or a cross-feature data-layer caller — both
  violate the barrel/layering rules. DECISION: D8's pre-sanctioned fallback
  applies — sequential, sale-first, per-line (matching the existing loop);
  a stock-write failure after a successful sale logs via the Plan 09 error
  path, the sale stands, recovery is manual adjustment. Money correctness
  outranks stock.
- V3: `_ProductTile` (products_screen.dart:70) has NO row `onTap` — edit
  and deactivate are trailing IconButtons (pushNamed productForm with
  extra: product at line 93-97; delete → confirm dialog). The action sheet
  replaces those trailing affordances; tests asserting direct-edit
  navigation must be updated.
- V4: settings save path is `IdentityRepository.updatePharmacySettings`
  (identity_repository.dart:26-28) with named params, implemented inside
  `_db.transaction` (identity_repository_impl.dart:100-121); column-add
  precedent is the v5 migration (m.addColumn on `pharmacies`). No streaming
  pharmacy provider exists — the deduct coordinator needs a fresh read of
  the flag at confirm time.
- V5: `activityFeedProvider` (activity_providers.dart:13-35) is a single
  `watchEntries(limit: 100)` stream → ActivityRow.fromEntry with
  one-time profile names. GAP FOUND: StockRepository has no all-pharmacy
  movement stream (aggregate map + single-product reads only) — the D2
  feed merge requires a new `watchMovements(pharmacyId)` read plus
  ActivityRow generalization; D10 filter (stock_in/adjustment only) and
  100-combined cap confirmed. In scope, planned not improvised.
- V6: baseline must be measured empirically at execution start (do not
  carry 225 forward per plan §4).

Watch-items from staff engineer (non-blocking, implemented in this plan):
(1) row needs a tappable cue (chevron) since icon affordances move into
   the sheet — don't ship an invisible gesture; (2) sheet labels must be
   unambiguous side-by-side — "تعديل المخزون" vs "تعديل المنتج" lead with
   the same word; differentiate (stock: "المخزون: إضافة / تصحيح", product:
   "تعديل بيانات المنتج"); (3) auto_deduct flag and on-hand map must be
   read FRESH inside the confirm handler, so a Settings toggle change takes
   effect on the very next sale.

## 2026-08-13 — Plan 13 confirmed decisions D6–D10 (recorded verbatim from PLANS/13 §3)
- D6 — Auto-deduct applies only to tracked products. Tracked = has ≥1
  movement. Selling an untracked product never creates a movement, even
  with auto-deduct ON — you cannot subtract from a quantity that was never
  declared, and a phantom negative would contradict the tracked-vs-zero
  distinction Plan 12 established. Tracking activates per product with its
  first movement.
- D7 — Adjustment is two modes with a live preview. Add mode posts
  `stock_in` (+qty, qty ≥ 1). Correct mode posts `adjustment` with delta =
  target − current on-hand (target ≥ 0; absent on-hand counts as 0).
  Zero-delta corrections are rejected gracefully, never posted — no noise
  movements. `initial` remains creation-form-only.
- D8 — Sale-first ordering for the sale+stock_out pair. If a single drift
  transaction across the two writes is not achievable without
  restructuring, the sale ledger write must succeed first; a failed stock
  movement after a successful sale is logged via the Plan 09 error path
  and recoverable via manual adjustment. Money correctness outranks stock.
  Phase 0 determined: NOT achievable without restructuring → sequential,
  sale-first, per-line path applies (see phase-0 entry above).
- D9 — One `stock_out` movement per sale line, mirroring the sale.
  Auto-deduct never blocks or reorders a sale, regardless of resulting
  on-hand (negatives allowed per D3).
- D10 — Activity feed shows manual movements only. `stock_in` and
  `adjustment` appear in the feed attributed to the recording profile;
  auto `stock_out` does not get its own feed row — the sale row already
  represents the event, and doubling feed rows per sale violates the
  low-information-density principle. The movement ledger remains the full
  audit record.

## 2026-08-13 — Plan 13 emulator runtime pass (device leg): v7→v8 + live exercise PASSED
Data source: emulator-5556, pharmacy 14 "PharmacyTest" — the SAME device
that carried Plan 12's device-leg rehearsal data (Aspirin initial 100 +
untracked A/Paracetamol; remote ledger ph14 = 3 entries). Release APK
installed with `adb install -r` (data preserved, no run-as).
Before/after: dashboard balances identical (sales ١٠٠٫٠٠ / net ٤٠٫٠٠),
Aspirin on-hand ١٠٠ intact post-upgrade — v7→v8 upgrade preserved every
pre-existing row (matches the fixture-leg counts in `auto_deduct_
migration_test.dart`).
Live exercise (uiautomator dumps + remote psql):
1. Tracked sale Aspirin×1 (auto-deduct ON) → on-hand ١٠٠→٩٩. PASS
2. Untracked sale A×1 (ON) → on-hand stays —, no movement (D6). PASS
3. Toggle OFF in settings → Aspirin sale → on-hand stays ٩٩ (D8 flag
   read fresh inside confirm; Settings change applies to next sale). PASS
   Toggle restored to ON afterwards (checked=true via dump).
4. Manual add +5 on Aspirin → ٩٩→١٠٤, preview showed "بعد الإضافة: ١٠٤".
   PASS
5. Correct Aspirin → ١٢٠ (delta +16), preview "الفرق: ١٦ · الجديد: ١٢٠".
   PASS
6. Activity feed: "إضافة مخزون: Aspirin +٥" and "تصحيح مخزون: Aspirin +١٦"
   rendered attributed with product names and signed quantities, merged
   newest-first with the six sale rows; NO auto `stock_out` rows (D10)
   and no `initial` rows. PASS
7. Remote psql: pharmacy 14 ledger intact. The three new sales appeared
   pending at the time (this pass's APK lacked the backend defines — see
   the acceptance reconciliation entry below for the CLOSED resolution:
   ids 4–6 confirmed remote 13:20 with the correctly-configured build).
Suite 257/257, analyzer clean, release APK builds.

## 2026-08-13 — Plan 13 acceptance: test-count reconciliation + sync observation CLOSED (merge record)
- Counts reconcile to the measured truth: Plan 12 closed at 225/225 at
  commit `50a0492`. The "224 tests green" figures in the tracked-vs-zero
  review entry and the Plan 12 `FEATURES.md` line were momentary
  pre-`50a0492` measurements, not a vanished test. Plan 13 added 32:
  +1 auto-deduct migration test (`bacf355`), +0 (`3fe345d`, stale-rehearsal
  fixes only), +15 deduct matrix — 8 unit + 5 sales widgets + 2 toggle
  widgets (`007f9ce`), +8 adjustment sheet (`e3978fe`), +8 activity feed —
  5 unit + 3 widget (`58e6c1e`). 225 + 32 = 257, matching the source tally
  (3 + 84 core + 170 features) and both measured suite runs.
- Sync observation CLOSED 2026-08-13 ~13:20. The three Step-8 sales
  (ledger ids 4, 5, 6 — 5000/200/5000 minor) were confirmed remote in
  tenant 14 after reinstalling the release APK built WITH
  `--dart-define-from-file=.env.local`. Root cause of the earlier
  "pending" state: the Step-8 runtime-pass APK was built WITHOUT the
  backend defines — the scheduler's documented unconfigured-backend
  quiet no-op, not a backend pause (backend was up throughout; psql
  readable 12:43–13:25) and not device network (ping to
  vhzvvveikzmuzxzrgbsr.supabase.co OK at ~13:19). With the configured
  build the chip flipped to "آخر نسخة: 13:20" and all pending rows landed
  in one push. lesson: a release build's sync state is meaningless unless
  the APK carries the backend defines — the release gate must build with
  `.env.local`, always.
- The same push carried an extra row, id 7 (1000 minor, product 3,
  profile 1, 09:57:54 UTC), not attributable to any scripted Step-8 step.
  All sale writes go through the confirm dialog — no code path writes
  unattributed sales; most likely an unscripted tap during the live
  session. Logged for the record; no Plan 13 code impact.
- CI find: documented `.github/workflows/ci.yaml` (Plan 08; referenced in
  `DECISIONS.md`, `FEATURES.md`, `PROJECT_MEMORY.md`, `REVIEW_PACKAGE.md`)
  does NOT exist in the repo — no `.github/` directory, working tree
  mirrors origin/main. The pilot release gate currently rests on local
  gates (analyze + full suite + release APK build). Restoring `ci.yaml`
  on main is a follow-up before the pilot build.
- Plans 12 + 13 merged to main via merge commit `78e9f0f` (2026-08-13;
  `git merge --no-ff` + push — `gh` was unavailable on this machine, so
  no GitHub PR was created; the merge commit message carries the full
  PR-style description, Plans 12 AND 13, and the handoff notes).
  Plan 14 branches from main, not from the feature branch.

## 2026-08-13 — Plan 14 confirmed decisions D14–D16 (recorded verbatim from PLANS/14 §3)
- D14 — Signals apply only to tracked products. Untracked products never
  signal — a product with no declared quantity cannot be "low."
  Out-of-stock = tracked ∧ on-hand ≤ 0 (negative included — worse than
  zero, never hidden). Low = tracked ∧ threshold set ∧ 0 < on-hand ≤
  threshold. Threshold unset → out-of-stock signal only. Alternatives
  considered: global threshold (rejected — one number produces noise
  across heterogeneous products); out-of-stock-only MVP (rejected —
  under-delivers §4.2 item 4's "low or out of stock").
- D15 — Threshold is a nullable product column, editable at any time. It
  is configuration, not a movement — editing it posts nothing to the
  movement ledger. Integer ≥ 0, optional, Arabic-Indic input via the
  shared `normalizeDigits` path. (Note: a threshold of 0 adds nothing
  beyond the out-of-stock signal; helper copy should guide toward ≥ 1.)
- D16 — The expense insight follows the dashboard range selector
  (today/week/month) and hides entirely when the selected range has no
  expenses — no empty-state noise, per the low-information-density
  principle. Ties break deterministically (total, then category order).

## 2026-08-13 — Plan 14 Phase 0 verification gate: PASSED (V1–V5)
PLANS/14 Phase 0 report (branch `feature/14-inventory-signals` off
`a44eded`; no code changes in this entry):
- V1 `schemaVersion` == 8 on main (`app_database.dart:55`); v9 is the
  next slot. PASS
- V2 dashboard structure: `DashboardRangeSelector` at
  `dashboard_screen.dart:83`; profit card 85–120; the expense-insight
  slot fits between the profit card and the balances card (line 122).
  Products hub tile = `_NavTile` (155–159), shared by all six nav tiles
  with a chevron trailing — attention count implemented as a
  nullable-count parameter on `_NavTile` (other five tiles pass null;
  hidden-at-zero falls out for free). PASS
- V3 product tile post-Plan-13: `products_screen.dart:71–107` — `ListTile`,
  subtitle = price + on-hand line (untracked → "—"), trailing = delete +
  chevron, row-tap → action sheet. Badge anchor chosen: the TITLE row
  (name + chip), leaving the stock subtitle line and the tap affordance
  untouched; RTL collision risk flagged for the runtime pass. PASS
- V4 form/table precedent: `product_form_screen.dart` `_parseStock`
  normalizeDigits path (90–95) reused for threshold parsing; initial
  stock's movement-posting path (158–166) NOT reused — threshold is
  config (D15). Column-add precedent = v5/v8 `addColumn` steps. PASS
- V5 baseline RE-MEASURED: `flutter test` → 257/257, exact match with
  the Plan 13 closeout (225 + 32). No stop conditions hit.
- Note: `PLANS/14_INVENTORY_SIGNALS_AND_INSIGHTS_PLAN.md` itself was
  untracked on main (present in the working tree, never committed);
  committed with this entry.

## 2026-08-13 — lesson: drift watch streams never complete under widget-test fake-async
Diagnosed while writing the auto-deduct hook test (Plan 13 step 5): a
`watch()`-based repository read inside a widget test's fake-async zone
hangs `pumpAndSettle` forever — drift schedules zero-duration timers the
fake clock never fires. Pattern going forward: confirm-time reads that
must return a value inside a widget test use a ONE-SHOT drift
`get()`-based repository method (`allOnHand`), never `stream.first`;
`watch*` streams stay provider-only.

## 2026-08-13 — Plan 14 completion: schema v9 + signals & insights CLOSED (close-out package)
All six implementation steps landed on `feature/14-inventory-signals`
(off `a44eded`, main). Per-commit gates held throughout: `flutter analyze`
clean, full suite green, `unmountAndFlushDriftTimers` in widget-tearDown.
Merge/acceptance pending the Freemium MVP verification pass.

### Migration rehearsal record (AGENTS.md standing rule §8 — TWO legs)
- FIXTURE leg PASSED at migration commit `c50faf2`: new
  `test/core/data/low_stock_threshold_migration_test.dart` rehearses
  v8→v9 on a seeded copy (products/stock_movements/ledger rows intact;
  `low_stock_threshold` NULL for every pre-existing row; write +
  durability across reopen). Before/after counts: seeded rows exact-match,
  schemaVersion 8 → 9. Suite at that commit: 258/258 (= 257 +
  this one fixture test).
- The three older ladder rehearsal tests now reopen at HEAD (v9) and had
  to DROP `low_stock_threshold` in their rollback fixtures —
  `sync_quarantine` (v5→v6), `stock_movements` (v6→v7),
  `auto_deduct` (v7→v8) — heads bumped to schemaVersion 9. Same pattern
  the v8 column established; no test count change (0).
- DEVICE leg = Step 8 runtime pass (below): migration ran on REAL pilot
  data on emulator-5556 (release APK, same signing, `install -r`).

### Step 8 device-leg PASS — four signals verified on the v9 release APK
Pre-migration (v8 APK, tenant 14, read via uiautomator dumps — this
model cannot read screenshots): home dashboard figures صافي الربح ٩٠٫٠٠,
المبيعات ٢١٢٫٠٠, تكلفة ١٢٢٫٠٠, المصروفات ٠٫٠٠, balances zero;
products screen — A tracked ٩٥, Aspirin tracked ١٢٠, Paracetamol
untracked (—), no badges (structurally impossible on v8). Built
`app-release.apk` (74.8MB) WITH `--dart-define-from-file=.env.local` and
`adb install -r` — Streamed Install Success (same signing as the
Plan-13 APK → data preserved, not wiped). Post-migration dumps byte-
identical: same three products, same on-hand, no badges (all thresholds
NULL, no signal leak).
- Signal 1 (out-of-stock): sold A 95→٠ via the sales screen (stepper 94
  taps to qty 95, الإجمالي ١٩٠٫٠٠ ج.م, confirmed). Products screen now
  shows "A / نفد المخزون / ٢٫٠٠ ج.م / المخزون: ٠". Untracked
  Paracetamol shows NO badge at — (D14: untracked never signals). Dashboard
  profit updated consistently: ٢٧٩ = ٩٠ + (١٩٠−١).
- Signal 2 (low): edited Aspirin via the product form, typed 150 into the
  low-stock field (helper "اختياري — يُنبّه عندما يصل المخزون إلى هذا الحد فأقل"),
  saved. List now shows "Aspirin / مخزون منخفض / ... / المخزون: ١٢٠"
  (150 > 120). A keeps نفد المخزون. List badge count = 2.
- Signal 3 (insight): dashboard had NO أعلى مصروف line while المصروفات
  was ٠٫٠٠ (D16 empty-range hide, observed pre-expense). Recorded an
  expense إيجار ١٠٬٠٠٠٫٠٠ ج.م (category picker → إيجار; amount field
  10000; تسجيل المصروف; list shows "إيجار / ١٠٬٠٠٠٫٠٠ ج.م"). Dashboard now
  renders "أعلى مصروف: إيجار / ١٠٬٠٠٠٫٠٠ ج.م (١٠٠٪)", المصروفات
  ١٠٬٠٠٠٫٠٠, صافي الربح −٩٬٧٢١ (90 + 189 − 10000). Switching to هذا
  الأسبوع keeps the same insight (single expense is in-range; range
  recompute itself is locked by the widget suite).
- Signal 4 (count==list): products hub tile content-desc reads
  "المنتجات / ٢" equal to the 2 list badges (A نفد المخزون + Aspirin
  مخزون منخفض); count remained ٢ on the week range too.
- Backup chip updated on device to "آخر نسخة: 13/8/2026 15:36" — sync
  still active on the configured build.

### Test-count reconciliation (per step, traceable)
```
257  baseline (re-measured at Plan 14 start — matches Plan 13 closeout)
+1   migration rehearsal test (low_stock_threshold)   → 258  (c50faf2)
+8   signal derivation, D14 matrix (stock_signal_test) → 266  (71a39a6)
+6   threshold field, create+edit widget tests          → 272  (3c99977)
+6   product-list badges widget tests                   → 278  (d39018d)
+12  dashboard (8 TopExpense domain + 4 widget)        → 290  (1f7618e)
```
Total added: 33 (1+8+6+6+12); 257 + 33 = 290, matching both measured
suite runs (badge commit 278/278; dashboard commit 290/290). The
attention-count DROP assertion (resolve out-of-stock → healthy → count
2→1) was added to `dashboard_flow_test.dart` after closure review — it
extends the existing count test in place (live-state transition),
no count change (still 290).

## 2026-08-15 — Out-of-band test fix: D16 insight fixtures were week-relative (Saturday flake)

CONTEXT: at the brand-pass base gate (post-Plan-14 merge b6a1548, tree byte-identical
to verified 35bfaf1), two Plan 14 dashboard widget tests failed — only on Saturdays.
Root cause: the tests seeded their in-week expense at `now − 3 days`, but the week
starts on Saturday (`_startOfWeek`, dashboard_range.dart), so on a Saturday the week
contains only today and the fixture falls in the previous week. Pre-existing latent
flake, invisible to the 2026-08-13 close-out (Thursday); NOT a merge regression
(verified: empty diff between 35bfaf1 and b6a1548), NOT a production-code defect
(the insight logic is correct for the real calendar).

DECISION (staff-engineer directed, Option 1): dedicated test-only robustness commit,
landed on main BEFORE the brand branch is cut, so the brand pass stands on a
deterministic green gate. Fix: fixtures seed at yesterday-midnight via a new
`inWeekNotToday(now)` helper (strictly in-week, outside today, on every day except
Saturday); on Saturday the in-week-not-today scenario is unrepresentable (week ==
today), so the tests assert the degenerate case (recompute no-op / insight stays
hidden) instead of hardcoding a weekday-dependent expectation. Assertions otherwise
unchanged and still hardcoded (٣٫٠٠ ج.م (٦٠٪) / ٥٣٫٠٠ ج.م (٩٦٪)) — nothing weakened.
Clock injection (rangeOf already takes `now`) was rejected: the widget path calls
`DateTime.now()` at the provider, so injection would have required a production
change — forbidden by the test-only constraint.

RULE this introduces (standing): dashboard range fixtures must be relative to
`rangeOf(...)`-derived boundaries (or weekday-agnostic), never fixed `now − N days`
offsets, because the week starts on Saturday. 290/290 measured on the fixed build.
