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
