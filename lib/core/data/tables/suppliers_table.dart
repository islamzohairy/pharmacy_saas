import 'package:drift/drift.dart';

import 'pharmacies_table.dart';

/// Party the pharmacy owes money to. Referenced by `supplier_debt` and
/// `debt_repayment` ledger entries.
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `Supplier` entity.
@DataClassName('StoredSupplier')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().references(Pharmacies, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
