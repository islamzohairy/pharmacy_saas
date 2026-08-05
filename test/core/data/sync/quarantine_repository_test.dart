import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/sync/quarantine_repository.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';

import '../../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late QuarantineRepository repo;
  late int pharmacyA;
  late int pharmacyB;

  setUp(() async {
    db = await createMemoryDb();
    repo = QuarantineRepository(db);
    pharmacyA = await seedPharmacy(db);
    pharmacyB = await seedPharmacy(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('quarantine writes rows keyed per (pharmacy, entry) and reads them '
      'back as the exclusion set', () async {
    await repo.quarantine(
      pharmacyId: pharmacyA,
      entryIds: [1, 2, 3],
      code: '23503',
      message: 'Key (product_id)=(1) is not present in table "products"',
    );

    expect(await repo.quarantinedEntryIds(pharmacyId: pharmacyA), {1, 2, 3});
    expect(await repo.quarantinedEntryIds(pharmacyId: pharmacyB), isEmpty);
  });

  test('re-quarantining the same batch is idempotent (insert-or-ignore)', () async {
    await repo.quarantine(
      pharmacyId: pharmacyA,
      entryIds: [1, 2],
      code: '23503',
      message: 'first',
    );
    await repo.quarantine(
      pharmacyId: pharmacyA,
      entryIds: [2, 3],
      code: '23503',
      message: 'second',
    );

    expect(await repo.quarantinedEntryIds(pharmacyId: pharmacyA), {1, 2, 3});
    final rows = await db.select(db.syncQuarantineEntries).get();
    expect(rows, hasLength(3));
    expect(rows.where((r) => r.entryId == 2).single.message, 'first');
  });

  test('an empty batch is a no-op', () async {
    await repo.quarantine(
      pharmacyId: pharmacyA,
      entryIds: const [],
      code: '23503',
    );
    expect(await repo.quarantinedEntryIds(pharmacyId: pharmacyA), isEmpty);
  });

  test('long messages are truncated to the column limit', () async {
    await repo.quarantine(
      pharmacyId: pharmacyA,
      entryIds: [1],
      code: '23503',
      message: 'x' * 5000,
    );
    final rows = await db.select(db.syncQuarantineEntries).get();
    expect(rows.single.message!.length, lessThanOrEqualTo(2048));
  });

  test('lastSyncedAt is unaffected by quarantine: quarantine never touches '
      'ledger rows, the derived stamp comes only from synced entries',
      () async {
    final stamp = DateTime.utc(2026, 8, 4, 9, 30);
    await db.into(db.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            pharmacyId: pharmacyA,
            type: LedgerEntryType.sale,
            amountMinor: 100,
            occurredAt: DateTime(2026, 8, 1),
            syncedAt: Value(stamp),
          ),
        );
    await repo.quarantine(
      pharmacyId: pharmacyA,
      entryIds: [42],
      code: '22P02',
      message: 'bad enum value',
    );

    final maxAt = db.ledgerEntries.syncedAt.max();
    final row = await (db.selectOnly(db.ledgerEntries)
          ..addColumns([maxAt])
          ..where(
            db.ledgerEntries.pharmacyId.equals(pharmacyA) &
                db.ledgerEntries.syncedAt.isNotNull(),
          ))
        .getSingleOrNull();
    expect(row?.read(maxAt)?.toUtc(), stamp);
    expect(await db.select(db.syncQuarantineEntries).get(), hasLength(1));
  });
}
