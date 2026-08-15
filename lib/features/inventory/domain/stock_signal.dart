/// The pure stock-signal rule (PLANS/14 §5.2, D14): which products need
/// the owner's attention.
///
/// Deliberately a plain function over primitive inputs — no drift, no
/// providers — so the rule is trivially testable independent of storage.
/// Products presentation and the dashboard provider both call this; no
/// widget computes signal state.
///
/// Guarantees, all unit-tested:
/// - untracked (null on-hand) never signals — a product with no declared
///   quantity cannot be "low";
/// - on-hand ≤ 0 is out of stock, negative included — worse than zero,
///   never clamped, never hidden (D3 lineage);
/// - low requires a SET threshold and 0 < on-hand ≤ threshold — threshold
///   unset means out-of-stock signal only;
/// - threshold 0 adds nothing beyond the out-of-stock signal.
enum StockSignal { none, low, outOfStock }

StockSignal stockSignal({required int? onHand, int? threshold}) {
  if (onHand == null) return StockSignal.none;
  if (onHand <= 0) return StockSignal.outOfStock;
  if (threshold != null && onHand <= threshold) return StockSignal.low;
  return StockSignal.none;
}