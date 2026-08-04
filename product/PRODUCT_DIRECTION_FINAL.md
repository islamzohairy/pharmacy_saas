# Product Direction — Final
## Confirmed Product Decisions, Reconciled Against the Delivery Plan and the Live Repository
### For the Staff Engineer

**Purpose:** This closes out the four decisions left open after the last review, and reconciles them against the actual code at `github.com/islamzohairy/pharmacy_saas` — not just the plans. Three of the four already match what's built. One does not and needs a concrete scope adjustment, documented below with a final call rather than left open.

**Authority, unchanged:** confirmed product decisions > real customer evidence > original simulated research > needs investigation. This document is now the authoritative product-direction source for the four items below; `DECISIONS.md` in the repo should be updated to reflect it.

---

## 1. Resolved Decisions

### (a) Identity / Account Strategy — Hybrid onboarding, confirmed
**Decision:** MVP works fully locally, no account required; accounts arrive later for backup, sync, recovery, multi-device.

**Repo review finding: already built this way, no change needed.** `PLANS/02_IDENTITY_AND_ACCESS_PLAN.md` and the actual `lib/features/identity/` code create a local `Pharmacy` + owner `UserProfile` on first launch with zero network calls, support a second local "family" profile for the shift-sharing pattern via a profile switcher (not a login screen), and gate switching with an optional local PIN. No Supabase Auth call exists anywhere in the identity feature — the only Supabase usage in the codebase is a separate backup/sync layer (`core/data/sync/`), which is exactly the "accounts later, for backup/sync" shape this decision describes. This is validated, not just planned.

**One thing to keep watching:** the `role` field (`owner` / `family` / `employee`) is captured but deliberately not enforced yet — an `employee` profile currently has identical access to `owner`. The plan explicitly warns against letting in-app copy imply otherwise. That's the right call for now and lines up with decision (c) below.

### (b) Owner Cash Draw Tracking — Expense subtype, confirmed, requires a real scope change
**Decision:** "Owner Draw" should be a category under Expenses, not its own module.

**Repo review finding: this does not match what's built, and it's not just a labeling issue.** The current ledger schema (`LedgerEntryType`: `sale`, `cashDraw`, `supplierDebt`, `customerDebt`, `debtRepayment`) has **no general "expense" concept at all** — `cashDraw` is a peer entry type, not a category within a broader expense type. In the app, `Draws` is its own top-level route (`/draws`) with its own screen, wired directly into navigation alongside Sales, Products, and the dashboard — exactly the "separate financial module" this decision says to avoid.

There's also a real gap this surfaces: **general business expenses (rent, utilities, supplies, other) aren't tracked anywhere yet** — only owner draws are. Decision 6's Financial Control list names "expenses" as its own item, distinct from cash draws. As built, that item doesn't exist; only one category of it does.

**Final decision:** consolidate into a single "Expenses" area with a category field (e.g., Owner Draw, Rent, Utilities, Supplies, Other), and remove the standalone `/draws` top-level nav entry in favor of an Expenses entry point. This is both a reorganization of what's already built and a small scope addition (general expense categories didn't exist before). Whether that's a new `expense` ledger type with a category attribute, or a category field added directly to the existing `cashDraw`-style entries, is an implementation choice for the Staff Engineer — the product requirement is the single Expenses surface with Owner Draw as one entry in it, not two parallel concepts in the UI.

### (c) Employee Activity Auditing — Basic activity history, confirmed, cheap to build on what exists
**Decision:** show who did what and when for important actions; no full enterprise auditing.

**Repo review finding: no activity-history screen exists yet, but the data already supports it.** Every `LedgerEntry` already carries a `profileId`, meaning every sale, draw, debt entry, and repayment is already attributed to whichever local profile was active when it was recorded. Building a simple "recent activity" list (who, what, when) is additive on top of data that already exists — it doesn't require a schema change, just a screen and a query. This is a low-cost way to deliver decision (c) without building the fuller audit trail the earlier plan had originally scoped.

### (d) E-Invoice / E-Receipt Compliance — Basic prep in MVP, confirmed, already has a safe gate to build against
**Decision:** handle required business info/settings where needed; no full government integration yet.

**Repo review finding: the repo already has an appropriately cautious compliance gate (`COMPLIANCE.md`)** — the e-invoicing/e-receipt item is explicitly marked `unconfirmed` and blocked from any implementation plan until it's `confirmed-by-counsel` against actual ETA guidance, not just the product spec's compliance-guide summary. That gate is correct and should stay exactly as-is.

**Final decision:** "basic compliance preparation" means adding optional business/tax-registration fields to pharmacy settings (e.g., tax registration number, legal business name) so the data exists if/when the integration is later confirmed — this is data capture, not compliance implementation, so it doesn't need to wait on the `confirmed-by-counsel` gate. The actual e-invoice/e-receipt integration stays fully behind that gate, unchanged.

## 2. Updated Final MVP Scope (supersedes Section 4 of the prior version of this document)

**Financial Control**
- Sales recording — simple, product-linked, not a full POS, not barcode-driven
- **Expenses** — general category (rent, utilities, supplies, other) with **Owner Draw as one category within it**, not a separate feature
- Profit visibility, net of all expenses including owner draws
- Customer debt — identity, balance, payment history, settlement
- Supplier debt — identity, balance, payment tracking, contact info

**Inventory (basic only)** — unchanged from the prior version of this document.

**Executive Overview** — unchanged.

**Operational Experience**
- Arabic-first UI, RTL, Egyptian terminology
- Offline-first throughout
- Guided, skippable onboarding
- Local-only owner/family/employee profiles — **validated as already built correctly**
- A simple activity history (who did what, when), built on existing per-entry attribution
- Progressive, high-value notifications (unchanged)
- Optional business/tax-registration fields in settings, for future compliance readiness — no functional compliance behavior yet

## 3. What the Staff Engineer Needs to Do Differently From What's Already Planned

- **No changes needed to identity/access.** It already matches the confirmed decision; treat `PLANS/02_IDENTITY_AND_ACCESS_PLAN.md` as validated, not just as a plan.
- **Restructure draws under a general Expenses area.** Remove `/draws` as a standalone top-level route; add general expense categories; Owner Draw becomes one category, not a parallel concept.
- **Add a simple activity-history view**, reading existing `profileId` attribution already present on every ledger entry — no schema change required for this one.
- **Add optional business/tax-registration fields to pharmacy settings** as inert data capture, fully separate from and without touching the existing `COMPLIANCE.md` gate on the actual e-invoice/e-receipt integration.

## 4. Open Questions — None Blocking, One Worth a Quick Call

- What specific expense categories belong in MVP beyond Owner Draw (rent, utilities, supplies, other — some reasonable starter set)? Small product detail, not a strategic decision — pick a short starter list and let owners add free-text notes rather than trying to enumerate every category up front.

Everything else from the prior open-questions list is now resolved by this document.
