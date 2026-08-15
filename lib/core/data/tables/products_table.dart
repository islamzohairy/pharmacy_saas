import 'package:drift/drift.dart';

import 'pharmacies_table.dart';

/// Product catalog entry. Money columns are INTEGER minor units
/// (piastres) — never REAL/float (ARCHITECTURE.md).
///
/// `isActive` enables soft deactivation (plan 05): historical `sale`
/// ledger entries must retain a valid `product_id` reference, so a product
/// is never hard-deleted once it exists.
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `Product` entity.
@DataClassName('StoredProduct')
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().references(Pharmacies, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get costMinor => integer()();
  IntColumn get sellMinor => integer()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  /// Low-stock signal threshold (PLANS/14, schema v9). Nullable and
  /// optional: unset means "out-of-stock signal only" (D14/D15). This is
  /// configuration, not a stock movement — editing it never posts to
  /// `stock_movements`.
  IntColumn get lowStockThreshold => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
