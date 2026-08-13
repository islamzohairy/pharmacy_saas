import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/stock_movement_type.dart';

/// Wire-name regression guard (Plan 10 lesson): inventory is local-only
/// today, but the snake_case wire convention is maintained so the wire
/// format is honest if stock movements ever sync. The compiler forces
/// every new member to declare its wire form; this test pins the values.
void main() {
  test('StockMovementType wireNames are snake_case', () {
    expect(StockMovementType.initial.wireName, 'initial');
    expect(StockMovementType.stockIn.wireName, 'stock_in');
    expect(StockMovementType.stockOut.wireName, 'stock_out');
    expect(StockMovementType.adjustment.wireName, 'adjustment');
  });
}