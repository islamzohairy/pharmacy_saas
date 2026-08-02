import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/sales/domain/record_sale.dart';

import '../../support/fake_ledger_repository.dart';

void main() {
  const pharmacyId = 1;
  const productId = 4;
  const profileId = 7;

  late FakeLedgerRepository repository;

  setUp(() {
    repository = FakeLedgerRepository();
  });

  group('recordSale', () {
    test('appends one sale entry priced at sellMinor x quantity', () async {
      final occurredAt = DateTime(2026, 8, 2, 18, 30);

      final entry = await recordSale(
        repository,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 3,
        sellMinor: 2550,
        occurredAt: occurredAt,
        profileId: profileId,
        note: 'كشف حساب عادي',
      );

      expect(repository.entries, hasLength(1));
      expect(entry.id, 1);
      expect(entry.type, LedgerEntryType.sale);
      expect(entry.amountMinor, 2550 * 3);
      expect(entry.productId, productId);
      expect(entry.supplierId, isNull);
      expect(entry.customerId, isNull);
      expect(entry.occurredAt, occurredAt);
      expect(entry.profileId, profileId);
      expect(entry.note, 'كشف حساب عادي');
    });

    test('a single unit records the unit price unchanged', () async {
      await recordSale(
        repository,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 1,
        sellMinor: 1250,
      );

      expect(repository.entries.single.amountMinor, 1250);
    });

    test('defaults occurredAt to now when omitted', () async {
      final before = DateTime.now();
      final entry = await recordSale(
        repository,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 1,
        sellMinor: 100,
      );
      final after = DateTime.now();

      expect(entry.occurredAt.isBefore(before), isFalse);
      expect(entry.occurredAt.isAfter(after), isFalse);
    });

    test('rejects zero and negative quantities before reaching the '
        'repository', () async {
      await expectLater(
        recordSale(
          repository,
          pharmacyId: pharmacyId,
          productId: productId,
          quantity: 0,
          sellMinor: 100,
        ),
        throwsArgumentError,
      );
      await expectLater(
        recordSale(
          repository,
          pharmacyId: pharmacyId,
          productId: productId,
          quantity: -2,
          sellMinor: 100,
        ),
        throwsArgumentError,
      );
      expect(repository.entries, isEmpty);
    });

    test('rejects zero and negative sell prices', () async {
      await expectLater(
        recordSale(
          repository,
          pharmacyId: pharmacyId,
          productId: productId,
          quantity: 1,
          sellMinor: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        recordSale(
          repository,
          pharmacyId: pharmacyId,
          productId: productId,
          quantity: 1,
          sellMinor: -50,
        ),
        throwsArgumentError,
      );
      expect(repository.entries, isEmpty);
    });
  });
}
