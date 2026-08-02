import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/ledger/data/ledger_repository_impl.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';

import '../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late DriftLedgerRepository repository;
  late int pharmacyId;
  late int profileId;

  setUp(() async {
    db = await createMemoryDb();
    repository = DriftLedgerRepository(db);
    pharmacyId = await seedPharmacy(db);
    profileId = await seedProfile(db, pharmacyId);
  });

  tearDown(() async {
    await db.close();
  });

  LedgerEntryDraft draft({
    LedgerEntryType type = LedgerEntryType.cashDraw,
    int amount = 1000,
    DateTime? occurredAt,
    int? supplierId,
    int? customerId,
  }) {
    return LedgerEntryDraft(
      pharmacyId: pharmacyId,
      type: type,
      amountMinor: amount,
      occurredAt: occurredAt ?? DateTime(2026, 8, 2, 10),
      supplierId: supplierId,
      customerId: customerId,
      profileId: profileId,
    );
  }

  test('append creates exactly one entry, attributed and typed', () async {
    final entry = await repository.append(draft());

    expect(entry.id, greaterThan(0));
    expect(entry.pharmacyId, pharmacyId);
    expect(entry.type, LedgerEntryType.cashDraw);
    expect(entry.amountMinor, 1000);
    expect(entry.profileId, 1);
    expect(entry.syncedAt, isNull);

    final all = await repository.watchEntries(pharmacyId: pharmacyId).first;
    expect(all, hasLength(1));
  });

  test('watchEntries filters by type and date range', () async {
    await repository.append(
      draft(
        type: LedgerEntryType.sale,
        amount: 5000,
        occurredAt: DateTime(2026, 8, 1, 9),
      ),
    );
    await repository.append(
      draft(
        type: LedgerEntryType.cashDraw,
        amount: 700,
        occurredAt: DateTime(2026, 8, 3, 9),
      ),
    );

    final sales = await repository
        .watchEntries(pharmacyId: pharmacyId, type: LedgerEntryType.sale)
        .first;
    expect(sales, hasLength(1));
    expect(sales.single.amountMinor, 5000);

    final august2 = await repository
        .watchEntries(
          pharmacyId: pharmacyId,
          from: DateTime(2026, 8, 2),
          to: DateTime(2026, 8, 2, 23, 59),
        )
        .first;
    expect(august2, isEmpty);
  });

  test('entriesByParty returns only the party requested', () async {
    final supplierId = await db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(pharmacyId: pharmacyId, name: 'مورد'),
        );
    final customerId = await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(pharmacyId: pharmacyId, name: 'عميل'),
        );

    await repository.append(
      draft(type: LedgerEntryType.supplierDebt, supplierId: supplierId),
    );
    await repository.append(
      draft(type: LedgerEntryType.customerDebt, customerId: customerId),
    );
    await repository.append(
      draft(type: LedgerEntryType.debtRepayment, supplierId: supplierId),
    );

    final supplierEntries = await repository
        .watchEntriesByParty(
          pharmacyId: pharmacyId,
          type: LedgerEntryType.supplierDebt,
          partyId: supplierId,
        )
        .first;
    expect(supplierEntries, hasLength(1));
  });

  test(
    'unsynced → markSynced → unsynced empty, backlog stream follows',
    () async {
      final a = await repository.append(draft());
      final b = await repository.append(draft(amount: 200));

      final unsynced = await repository.unsyncedEntries(pharmacyId: pharmacyId);
      expect(unsynced.map((e) => e.id), [a.id, b.id]);

      final counts = <int>[];
      final sub = repository
          .watchUnsyncedCount(pharmacyId: pharmacyId)
          .listen(counts.add);
      await _waitForBacklog(counts, 2);

      await repository.markSynced(
        pharmacyId: pharmacyId,
        ids: [a.id, b.id],
        at: DateTime.now().toUtc(),
      );
      await _waitForBacklog(counts, 0);
      expect(await repository.unsyncedEntries(pharmacyId: pharmacyId), isEmpty);

      await sub.cancel();
    },
  );

  test('markSynced never touches business fields', () async {
    final a = await repository.append(draft(amount: 555));
    final stamped = DateTime.utc(2026, 8, 2, 12);

    await repository.markSynced(
      pharmacyId: pharmacyId,
      ids: [a.id],
      at: stamped,
    );

    final row = await (db.select(
      db.ledgerEntries,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.amountMinor, 555);
    expect(row.syncedAt?.toUtc(), stamped);
  });

  test('negative amounts are rejected at the database', () async {
    await expectLater(
      repository.append(draft(amount: -1)),
      throwsA(isA<SqliteException>()),
    );
  });

  test(
    'a party referenced by the ledger cannot be deleted (FK RESTRICT)',
    () async {
      final supplierId = await db
          .into(db.suppliers)
          .insert(
            SuppliersCompanion.insert(pharmacyId: pharmacyId, name: 'مورد'),
          );
      await repository.append(
        draft(type: LedgerEntryType.supplierDebt, supplierId: supplierId),
      );

      await expectLater(
        db.delete(db.suppliers).go(),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test(
    'the append-only ledger has no update/delete path in its interface',
    () async {
      final source = await File(
        'lib/features/ledger/domain/ledger_repository.dart',
      ).readAsString();
      final withoutComments = source
          .replaceAll(RegExp(r'///.*'), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      expect(
        RegExp(r'\b(update|delete)\s*\(').hasMatch(withoutComments),
        isFalse,
        reason:
            'LedgerRepository must not expose update/delete members — '
            'corrections are new offsetting rows.',
      );
    },
  );

  test(
    'repositories are keyed to the pharmacy (tenant isolation local)',
    () async {
      final otherPharmacyId = await seedPharmacy(db, remoteUuid: 'other');
      await repository.append(draft());

      final otherBacklog = await repository.unsyncedEntries(
        pharmacyId: otherPharmacyId,
      );
      expect(otherBacklog, isEmpty);
      final ownBacklog = await repository.unsyncedEntries(
        pharmacyId: pharmacyId,
      );
      expect(ownBacklog, hasLength(1));
    },
  );
}

/// Polls a drift stream query until it reports [target] (drift emits
/// asynchronously via its background isolate).
Future<void> _waitForBacklog(List<int> counts, int target) async {
  for (var i = 0; i < 100; i++) {
    if (counts.isNotEmpty && counts.last == target) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('backlog stream never reported $target; saw $counts');
}
