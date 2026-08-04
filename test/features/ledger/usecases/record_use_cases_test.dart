import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/expense_category.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/ledger/domain/usecases/record_customer_debt.dart';
import 'package:pharmacy_saas/features/ledger/domain/usecases/record_expense.dart';
import 'package:pharmacy_saas/features/ledger/domain/usecases/record_repayment.dart';
import 'package:pharmacy_saas/features/ledger/domain/usecases/record_supplier_debt.dart';

import '../../../support/fake_ledger_repository.dart';

void main() {
  const pharmacyId = 1;
  const profileId = 7;

  late FakeLedgerRepository repository;

  setUp(() {
    repository = FakeLedgerRepository();
  });

  group('recordExpense', () {
    test('appends exactly one attributed expense entry with its category',
        () async {
      final occurredAt = DateTime(2026, 8, 2, 18, 30);

      final entry = await recordExpense(
        repository,
        pharmacyId: pharmacyId,
        category: ExpenseCategory.ownerDraw,
        amountMinor: 5000,
        occurredAt: occurredAt,
        profileId: profileId,
        note: 'مصروف شخصي',
      );

      expect(repository.entries, hasLength(1));
      expect(entry.id, 1);
      expect(entry.type, LedgerEntryType.expense);
      expect(entry.category, ExpenseCategory.ownerDraw);
      expect(entry.amountMinor, 5000);
      expect(entry.occurredAt, occurredAt);
      expect(entry.profileId, profileId);
      expect(entry.supplierId, isNull);
      expect(entry.customerId, isNull);
      expect(entry.note, 'مصروف شخصي');
    });

    test('records each category without mixing them up', () async {
      for (final category in ExpenseCategory.values) {
        await recordExpense(
          repository,
          pharmacyId: pharmacyId,
          category: category,
          amountMinor: 100,
        );
      }

      expect(repository.entries, hasLength(ExpenseCategory.values.length));
      for (final entry in repository.entries) {
        expect(entry.type, LedgerEntryType.expense);
        expect(entry.category, isNotNull);
      }
    });

    test('defaults occurredAt to now when omitted', () async {
      final before = DateTime.now();
      final entry = await recordExpense(
        repository,
        pharmacyId: pharmacyId,
        category: ExpenseCategory.other,
        amountMinor: 100,
      );
      final after = DateTime.now();

      expect(entry.occurredAt.isBefore(before), isFalse);
      expect(entry.occurredAt.isAfter(after), isFalse);
    });

    test(
      'rejects zero and negative amounts before reaching the repository',
      () async {
        await expectLater(
          recordExpense(
            repository,
            pharmacyId: pharmacyId,
            category: ExpenseCategory.rent,
            amountMinor: 0,
          ),
          throwsArgumentError,
        );
        await expectLater(
          recordExpense(
            repository,
            pharmacyId: pharmacyId,
            category: ExpenseCategory.rent,
            amountMinor: -1,
          ),
          throwsArgumentError,
        );
        expect(repository.entries, isEmpty);
      },
    );
  });

  group('recordSupplierDebt', () {
    test('appends exactly one attributed supplierDebt entry', () async {
      final entry = await recordSupplierDebt(
        repository,
        pharmacyId: pharmacyId,
        supplierId: 3,
        amountMinor: 12000,
        profileId: profileId,
      );

      expect(repository.entries, hasLength(1));
      expect(entry.type, LedgerEntryType.supplierDebt);
      expect(entry.supplierId, 3);
      expect(entry.customerId, isNull);
      expect(entry.profileId, profileId);
    });

    test('rejects zero and negative amounts', () async {
      await expectLater(
        recordSupplierDebt(
          repository,
          pharmacyId: pharmacyId,
          supplierId: 3,
          amountMinor: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        recordSupplierDebt(
          repository,
          pharmacyId: pharmacyId,
          supplierId: 3,
          amountMinor: -5,
        ),
        throwsArgumentError,
      );
      expect(repository.entries, isEmpty);
    });
  });

  group('recordCustomerDebt', () {
    test('appends exactly one attributed customerDebt entry', () async {
      final entry = await recordCustomerDebt(
        repository,
        pharmacyId: pharmacyId,
        customerId: 9,
        amountMinor: 800,
        profileId: profileId,
      );

      expect(repository.entries, hasLength(1));
      expect(entry.type, LedgerEntryType.customerDebt);
      expect(entry.customerId, 9);
      expect(entry.supplierId, isNull);
      expect(entry.profileId, profileId);
    });

    test('rejects zero and negative amounts', () async {
      await expectLater(
        recordCustomerDebt(
          repository,
          pharmacyId: pharmacyId,
          customerId: 9,
          amountMinor: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        recordCustomerDebt(
          repository,
          pharmacyId: pharmacyId,
          customerId: 9,
          amountMinor: -5,
        ),
        throwsArgumentError,
      );
      expect(repository.entries, isEmpty);
    });
  });

  group('recordRepayment', () {
    test('appends a repayment to a supplier', () async {
      final entry = await recordRepayment(
        repository,
        pharmacyId: pharmacyId,
        supplierId: 3,
        amountMinor: 4000,
        profileId: profileId,
      );

      expect(repository.entries, hasLength(1));
      expect(entry.type, LedgerEntryType.debtRepayment);
      expect(entry.supplierId, 3);
      expect(entry.customerId, isNull);
      expect(entry.profileId, profileId);
    });

    test('appends a repayment from a customer', () async {
      final entry = await recordRepayment(
        repository,
        pharmacyId: pharmacyId,
        customerId: 9,
        amountMinor: 300,
        profileId: profileId,
      );

      expect(repository.entries, hasLength(1));
      expect(entry.type, LedgerEntryType.debtRepayment);
      expect(entry.customerId, 9);
      expect(entry.supplierId, isNull);
      expect(entry.profileId, profileId);
    });

    test('rejects a repayment naming both parties', () async {
      await expectLater(
        recordRepayment(
          repository,
          pharmacyId: pharmacyId,
          supplierId: 3,
          customerId: 9,
          amountMinor: 500,
        ),
        throwsArgumentError,
      );
      expect(repository.entries, isEmpty);
    });

    test('rejects a repayment naming no party', () async {
      await expectLater(
        recordRepayment(repository, pharmacyId: pharmacyId, amountMinor: 500),
        throwsArgumentError,
      );
      expect(repository.entries, isEmpty);
    });

    test('rejects zero and negative amounts', () async {
      await expectLater(
        recordRepayment(
          repository,
          pharmacyId: pharmacyId,
          supplierId: 3,
          amountMinor: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        recordRepayment(
          repository,
          pharmacyId: pharmacyId,
          supplierId: 3,
          amountMinor: -5,
        ),
        throwsArgumentError,
      );
      expect(repository.entries, isEmpty);
    });
  });
}
