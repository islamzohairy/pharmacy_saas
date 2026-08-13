/// The four stock movement kinds a product can have. Defined at the
/// schema layer (not in a feature) because `core/` must not import feature
/// code — the inventory feature re-exposes it through its domain barrel
/// (same pattern as [LedgerEntryType]).
///
/// `quantity` on a movement is a signed delta: `initial`/`stock_in` are
/// positive, `stock_out` is negative, `adjustment` is whatever sign the
/// correction takes. On-hand is always the live SUM of quantities —
/// never a stored counter (PLANS/12 D1).
///
/// Snake_case `wireName`s maintained per the Plan 10 lesson even though
/// stock movements are local-only in P0: the compiler forces every new
/// type to declare its wire form, so the convention survives if inventory
/// ever syncs.
enum StockMovementType {
  initial,
  stockIn,
  stockOut,
  adjustment;

  String get wireName => switch (this) {
    StockMovementType.initial => 'initial',
    StockMovementType.stockIn => 'stock_in',
    StockMovementType.stockOut => 'stock_out',
    StockMovementType.adjustment => 'adjustment',
  };
}