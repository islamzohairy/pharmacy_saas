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

  group('calculateTotalOwedToSuppliers', () {
    test('sums debts across all suppliers and subtracts their repayments', () {
      final entries = [
        entry(type: LedgerEntryType.supplierDebt, amount: 5000, supplierId: 1),
        entry(type: LedgerEntryType.supplierDebt, amount: 2000, supplierId: 2),
        entry(type: LedgerEntryType.debtRepayment, amount: 1500, supplierId: 1),
        // Customer-side repayment and sales never affect the supplier total.
        entry(type: LedgerEntryType.debtRepayment, amount: 9999, customerId: 9),
        entry(type: LedgerEntryType.sale, amount: 9999),
      ];

      expect(calculateTotalOwedToSuppliers(entries: entries), 5500);
    });

    test('matches the sum of the per-party calculator', () {
      final entries = [
        entry(type: LedgerEntryType.supplierDebt, amount: 5000, supplierId: 1),
        entry(type: LedgerEntryType.supplierDebt, amount: 2000, supplierId: 2),
        entry(type: LedgerEntryType.debtRepayment, amount: 1500, supplierId: 1),
      ];
      final perPartySum = [1, 2].fold<int>(
        0,
        (sum, id) =>
            sum + calculateOwedToSupplier(entries: entries, supplierId: id),
      );

      expect(calculateTotalOwedToSuppliers(entries: entries), perPartySum);
    });

    test('empty ledger owes zero, not an error', () {
      expect(calculateTotalOwedToSuppliers(entries: const []), 0);
    });
  });

  group('calculateTotalOwedByCustomers', () {
    test('sums debts across all customers and subtracts their repayments', () {
      final entries = [
        entry(type: LedgerEntryType.customerDebt, amount: 800, customerId: 9),
        entry(type: LedgerEntryType.customerDebt, amount: 200, customerId: 8),
        entry(type: LedgerEntryType.debtRepayment, amount: 300, customerId: 9),
        // Supplier-side repayment never affects the customer total.
        entry(type: LedgerEntryType.debtRepayment, amount: 9999, supplierId: 3),
      ];

      expect(calculateTotalOwedByCustomers(entries: entries), 700);
    });

    test('matches the sum of the per-party calculator', () {
      final entries = [
        entry(type: LedgerEntryType.customerDebt, amount: 800, customerId: 9),
        entry(type: LedgerEntryType.customerDebt, amount: 200, customerId: 8),
        entry(type: LedgerEntryType.debtRepayment, amount: 300, customerId: 9),
      ];
      final perPartySum = [8, 9].fold<int>(
        0,
        (sum, id) =>
            sum + calculateOwedByCustomer(entries: entries, customerId: id),
      );

      expect(calculateTotalOwedByCustomers(entries: entries), perPartySum);
    });

    test('empty ledger owes zero, not an error', () {
      expect(calculateTotalOwedByCustomers(entries: const []), 0);
    });
  });
}
