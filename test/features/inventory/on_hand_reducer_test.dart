import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/stock_movement_type.dart';
import 'package:pharmacy_saas/features/inventory/domain/on_hand_reducer.dart';
import 'package:pharmacy_saas/features/inventory/domain/stock_movement.dart';

/// Pure on-hand reducer business rules (PLANS/12 §7): empty → 0, initial
/// only, mixed in/out, negative passes through unclamped, SUM is
/// order-independent.
void main() {
  StockMovement movement({
    int quantity = 1,
    int productId = 1,
    StockMovementType type = StockMovementType.stockIn,
  }) {
    return StockMovement(
      id: 1,
      pharmacyId: 1,
      productId: productId,
      type: type,
      quantity: quantity,
      occurredAt: DateTime(2026, 8, 1),
    );
  }

  test('empty history reduces to zero', () {
    expect(reduceOnHand(const []), 0);
  });

  test('a single initial movement is its own on-hand', () {
    expect(reduceOnHand([movement(quantity: 12, type: StockMovementType.initial)]), 12);
  });

  test('mixed stock-in and stock-out sum correctly', () {
    final movements = [
      movement(quantity: 10, type: StockMovementType.initial),
      movement(quantity: 20, type: StockMovementType.stockIn),
      movement(quantity: -7, type: StockMovementType.stockOut),
      movement(quantity: 100, type: StockMovementType.stockIn),
    ];
    expect(reduceOnHand(movements), 123);
  });

  test('a negative result passes through unclamped (D3)', () {
    final movements = [
      movement(quantity: 5, type: StockMovementType.initial),
      movement(quantity: -9, type: StockMovementType.stockOut),
    ];
    expect(reduceOnHand(movements), -4);
  });

  test('sum is order-independent — reordering never changes the result', () {
    final a = movement(quantity: 13, type: StockMovementType.stockIn);
    final b = movement(quantity: -4, type: StockMovementType.stockOut);
    final c = movement(quantity: 2, type: StockMovementType.adjustment);
    final forward = [a, b, c];
    final reversed = [c, a, b];
    expect(reduceOnHand(forward), reduceOnHand(reversed));
    expect(reduceOnHand(forward), 11);
  });

  test('adjustment carries the sign of the correction', () {
    final movements = [
      movement(quantity: 30, type: StockMovementType.initial),
      movement(quantity: 5, type: StockMovementType.adjustment),
      movement(quantity: -2, type: StockMovementType.adjustment),
    ];
    expect(reduceOnHand(movements), 33);
  });
}