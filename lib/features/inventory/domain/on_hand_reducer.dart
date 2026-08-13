import 'stock_movement.dart';

/// The pure on-hand business rule: on-hand = SUM of all movement
/// quantities for a product. Deliberately a plain function over domain
/// entities — no drift, no providers — so the rule is trivially
/// testable independent of storage (PLANS/12 §5.2).
///
/// Guarantees, all unit-tested:
/// - empty history → 0;
/// - negative results pass through unclamped (D3 — stock may go
///   negative; never clamp, never block);
/// - SUM is order-independent — reordering movements never changes the
///   result.
int reduceOnHand(Iterable<StockMovement> movements) {
  var onHand = 0;
  for (final movement in movements) {
    onHand += movement.quantity;
  }
  return onHand;
}