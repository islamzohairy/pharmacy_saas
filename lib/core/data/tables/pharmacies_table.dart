import 'package:drift/drift.dart';

/// Tenant root. One row per install for P0 — `pharmacy_id` on every other
/// table is what makes tenant isolation load-bearing from the first
/// migration (ARCHITECTURE.md).
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `Pharmacy` entity.
@DataClassName('StoredPharmacy')
class Pharmacies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
