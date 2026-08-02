import 'package:drift/drift.dart';

import 'customers_table.dart';
import 'ledger_entry_type.dart';
import 'pharmacies_table.dart';
import 'products_table.dart';
import 'suppliers_table.dart';
import 'user_profiles_table.dart';

export 'ledger_entry_type.dart' show LedgerEntryType;

/// The append-only financial ledger. THE rule of this schema: rows are
/// never updated or deleted, by anyone, for any reason — a correction is a
/// new offsetting entry (ARCHITECTURE.md, DECISIONS.md).
///
/// This constraint is enforced above the table: `LedgerRepository`
/// exposes no update/delete path, and the sync path only stamps
/// `syncedAt` as bookkeeping. A correction is a new `ledger_entries` row.
///
/// Money is INTEGER minor units (piastres), never float. `type` follows
/// [LedgerEntryType]; only one party reference per row is set according
/// to the type.
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `LedgerEntry` entity.
@DataClassName('StoredLedgerEntry')
@TableIndex(name: 'idx_ledger_pharmacy_occurred_at', columns: {
  #pharmacyId,
  #occurredAt,
})
@TableIndex(name: 'idx_ledger_pharmacy_type', columns: {#pharmacyId, #type})
class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().references(Pharmacies, #id)();
  TextColumn get type => textEnum<LedgerEntryType>()
      .withLength(min: 4, max: 16)();
  IntColumn get amountMinor => integer().check(
    const CustomExpression<bool>('amount_minor >= 0'),
  )();
  IntColumn get productId => integer().references(Products, #id).nullable()();
  IntColumn get supplierId =>
      integer().references(Suppliers, #id).nullable()();
  IntColumn get customerId =>
      integer().references(Customers, #id).nullable()();
  IntColumn get profileId =>
      integer().references(UserProfiles, #id).nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}
