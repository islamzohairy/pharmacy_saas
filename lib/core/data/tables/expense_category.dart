/// The category of an `expense` ledger entry. Defined at the schema layer
/// (not in the expenses feature) because `core/` must not import feature
/// code — the ledger barrel re-exposes it, mirroring [LedgerEntryType]
/// (PLANS/10 Phase 1).
enum ExpenseCategory {
  /// Cash taken out of the pharmacy by the owner — the highest-frequency
  /// expense, and the old standalone `Draws` concept folded under Expenses
  /// (PRODUCT_DIRECTION_FINAL.md item (b)).
  ownerDraw,
  rent,
  utilities,
  supplies,
  other;

  /// Server-side whitelist of accepted remote values (migrations/
  /// 0002_expense_category.sql must stay in sync with this — the same
  /// snake_case contract as [LedgerEntryType.wireName]). Exhaustive on
  /// purpose, matching the Phase 0 wire-format fix: the compiler forces
  /// every future category to declare its wire form here.
  String get wireName => switch (this) {
    ExpenseCategory.ownerDraw => 'owner_draw',
    ExpenseCategory.rent => 'rent',
    ExpenseCategory.utilities => 'utilities',
    ExpenseCategory.supplies => 'supplies',
    ExpenseCategory.other => 'other',
  };
}