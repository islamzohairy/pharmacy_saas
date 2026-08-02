import 'package:drift/drift.dart';

import 'pharmacies_table.dart';

/// Party that owes money to the pharmacy. Referenced by `customer_debt`
/// and `debt_repayment` ledger entries.
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `Customer` entity.
@DataClassName('StoredCustomer')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().references(Pharmacies, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
