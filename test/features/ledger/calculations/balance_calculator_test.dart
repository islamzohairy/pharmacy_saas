import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/ledger/domain/calculations/balance_calculator.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';

void main() {
  LedgerEntry entry({
    required LedgerEntryType type,
    required int amount,
    int? supplierId,
    int? customerId,
  }) {
    return LedgerEntry(
      id: 0,
      pharmacyId: 1,
      type: type,
      amountMinor: amount,
      occurredAt: DateTime(2026, 8, 2, 12),
      supplierId: supplierId,
      customerId: customerId,
    );
  }

  group('calculateOwedToSupplier', () {
    test('debt minus repayments for one supplier, others ignored', () {
      final entries = [
        entry(type: LedgerEntryType.supplierDebt, amount: 5000, supplierId: 1),
        entry(type: LedgerEntryType.supplierDebt, amount: 2000, supplierId: 1),
        entry(type: LedgerEntryType.debtRepayment, amount: 1500, supplierId: 1),
        entry(type: LedgerEntryType.supplierDebt, amount: 9999, supplierId: 2),
        entry(type: LedgerEntryType.debtRepayment, amount: 9999, customerId: 9),
        entry(type: LedgerEntryType.sale, amount: 5000),
      ];

      expect(
        calculateOwedToSupplier(entries: entries, supplierId: 1),
        5500, // 5000 + 2000 − 1500
      );
    });

    test('overpayment yields a negative balance (credit), never clamped', () {
      final entries = [
        entry(type: LedgerEntryType.supplierDebt, amount: 1000, supplierId: 1),
        entry(type: LedgerEntryType.debtRepayment, amount: 1500, supplierId: 1),
      ];

      expect(calculateOwedToSupplier(entries: entries, supplierId: 1), -500);
    });

    test('a supplier with no entries owes zero, not an error', () {
      expect(calculateOwedToSupplier(entries: const [], supplierId: 5), 0);
    });
  });

  group('calculateOwedByCustomer', () {
    test('debt minus repayments for one customer, others ignored', () {
      final entries = [
        entry(type: LedgerEntryType.customerDebt, amount: 800, customerId: 9),
        entry(type: LedgerEntryType.debtRepayment, amount: 300, customerId: 9),
        entry(type: LedgerEntryType.customerDebt, amount: 9999, customerId: 8),
        entry(type: LedgerEntryType.debtRepayment, amount: 9999, supplierId: 3),
      ];

      expect(
        calculateOwedByCustomer(entries: entries, customerId: 9),
        500, // 800 − 300
      );
    });

    test('overpayment yields a negative balance (credit), never clamped', () {
      final entries = [
        entry(type: LedgerEntryType.customerDebt, amount: 500, customerId: 9),
        entry(type: LedgerEntryType.debtRepayment, amount: 700, customerId: 9),
      ];

      expect(calculateOwedByCustomer(entries: entries, customerId: 9), -200);
    });

    test('a customer with no entries owes zero, not an error', () {
      expect(calculateOwedByCustomer(entries: const [], customerId: 5), 0);
    });
  });
}
