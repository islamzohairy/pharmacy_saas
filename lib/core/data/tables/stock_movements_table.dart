import 'package:drift/drift.dart';

import 'pharmacies_table.dart';
import 'products_table.dart';
import 'stock_movement_type.dart';
import 'user_profiles_table.dart';

export 'stock_movement_type.dart' show StockMovementType;

/// The append-only stock movement ledger (PLANS/12 D1). The same rule as
/// the financial ledger: rows are never updated or deleted — on-hand
/// quantity is always computed live by aggregation, never stored as a
/// mutable counter. A correction is a new offsetting movement.
///
/// `quantity` is a signed integer delta (positive adds, negative
/// subtracts; D4 — plain integer units, no fractions). Only `initial` is
/// posted by Plan 12; `stock_in`/`stock_out`/`adjustment` arrive with
/// Plan 13's deduction/adjustment UI.
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `StockMovement` entity.
@DataClassName('StoredStockMovement')
@TableIndex(
  name: 'idx_stock_movement_pharmacy_product',
  columns: {#pharmacyId, #productId},
)
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().references(Pharmacies, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get type => textEnum<StockMovementType>()();
  IntColumn get quantity => integer()();
  DateTimeColumn get occurredAt => dateTime()();

  /// Caller-resolved attribution (plan-04 precedent); NULL allowed for
  /// system-initiated movements.
  IntColumn get profileId =>
      integer().references(UserProfiles, #id).nullable()();

  TextColumn get note => text().nullable()();
}