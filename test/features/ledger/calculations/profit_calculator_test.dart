import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/ledger/domain/calculations/profit_calculator.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';

void main() {
  LedgerEntry entry({
    required LedgerEntryType type,
    required int amount,
    DateTime? occurredAt,
    int? productId,
  }) {
    return LedgerEntry(
      id: 0,
      pharmacyId: 1,
      type: type,
      amountMinor: amount,
      occurredAt: occurredAt ?? DateTime(2026, 8, 2, 12),
      productId: productId,
    );
  }

  final costs = <int, int>{1: 2000, 2: 500};

  group('calculateProfit', () {
    test('mixed dataset over a range, covering all five entry types', () {
      final entries = <LedgerEntry>[
        entry(type: LedgerEntryType.sale, amount: 5000, productId: 1),
        entry(
          type: LedgerEntryType.sale,
          amount: 3000,
          productId: 2,
          occurredAt: DateTime(2026, 8, 3, 9),
        ),
        entry(
          type: LedgerEntryType.sale,
          amount: 1000,
          occurredAt: DateTime(2026, 8, 4, 9),
        ),
        entry(
          type: LedgerEntryType.sale,
          amount: 2000,
          productId: 99,
          occurredAt: DateTime(2026, 8, 5, 9),
        ),
        entry(type: LedgerEntryType.expense, amount: 700),
        entry(
          type: LedgerEntryType.supplierDebt,
          amount: 5000,
          occurredAt: DateTime(2026, 8, 2, 14),
        ),
        entry(
          type: LedgerEntryType.customerDebt,
          amount: 2000,
          occurredAt: DateTime(2026, 8, 2, 15),
        ),
        entry(
          type: LedgerEntryType.debtRepayment,
          amount: 1000,
          occurredAt: DateTime(2026, 8, 2, 16),
        ),
        entry(
          type: LedgerEntryType.sale,
          amount: 9999,
          productId: 1,
          occurredAt: DateTime(2026, 7, 1, 9),
        ),
        entry(
          type: LedgerEntryType.expense,
          amount: 500,
          occurredAt: DateTime(2026, 9, 1, 9),
        ),
      ];

      final profit = calculateProfit(
        entries: entries,
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31, 23, 59),
        costMinorOf: (productId) => costs[productId],
      );

      // sales = 5000 + 3000 + 1000 + 2000; cost = 2000 + 500 + 0 (no
      // product) + 0 (unknown product); expenses = 700. Debt entries are
      // ignored by profit entirely.
      expect(profit.salesMinor, 11000);
      expect(profit.costMinor, 2500);
      expect(profit.expensesMinor, 700);
      expect(profit.netMinor, 7800);
    });

    test('range boundaries are inclusive', () {
      final atFrom = entry(
        type: LedgerEntryType.sale,
        amount: 100,
        occurredAt: DateTime(2026, 8, 1),
      );
      final atTo = entry(
        type: LedgerEntryType.sale,
        amount: 200,
        occurredAt: DateTime(2026, 8, 31, 23, 59),
      );

      final profit = calculateProfit(
        entries: [atFrom, atTo],
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31, 23, 59),
        costMinorOf: (_) => 0,
      );

      expect(profit.salesMinor, 300);
    });

    test('zero entries yields an all-zero breakdown, never an error', () {
      final profit = calculateProfit(entries: const [], costMinorOf: (_) => 0);

      expect(profit.salesMinor, 0);
      expect(profit.costMinor, 0);
      expect(profit.expensesMinor, 0);
      expect(profit.netMinor, 0);
    });

    test('range with draws and no sales subtracts draws from zero', () {
      final profit = calculateProfit(
        entries: [entry(type: LedgerEntryType.expense, amount: 700)],
        costMinorOf: (_) => 0,
      );

      expect(profit.salesMinor, 0);
      expect(profit.costMinor, 0);
      expect(profit.expensesMinor, 700);
      expect(profit.netMinor, -700);
    });

    test('range with only debt entries yields zeros (plan 07 edge case)', () {
      final profit = calculateProfit(
        entries: [
          entry(type: LedgerEntryType.supplierDebt, amount: 5000),
          entry(type: LedgerEntryType.customerDebt, amount: 2000),
        ],
        costMinorOf: (_) => 0,
      );

      expect(profit.salesMinor, 0);
      expect(profit.costMinor, 0);
      expect(profit.expensesMinor, 0);
      expect(profit.netMinor, 0);
    });

    test(
      'expensesMinor sums expense entries across mixed categories '
      '(plan 10: profit is net of every expense, not just owner draws)',
      () {
        final profit = calculateProfit(
          entries: [
            entry(type: LedgerEntryType.expense, amount: 700),
            entry(
              type: LedgerEntryType.expense,
              amount: 1200,
              occurredAt: DateTime(2026, 8, 3, 10),
            ),
            entry(
              type: LedgerEntryType.expense,
              amount: 300,
              occurredAt: DateTime(2026, 9, 1, 9),
            ),
          ],
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 31, 23, 59),
          costMinorOf: (_) => 0,
        );

        expect(profit.expensesMinor, 1900);
        expect(profit.netMinor, -1900);
      },
    );

    test('a sale outside the range is excluded from both amount and cost', () {
      final entries = [
        entry(type: LedgerEntryType.sale, amount: 5000, productId: 1),
        entry(
          type: LedgerEntryType.sale,
          amount: 9000,
          productId: 1,
          occurredAt: DateTime(2026, 7, 31),
        ),
      ];

      final profit = calculateProfit(
        entries: entries,
        from: DateTime(2026, 8, 1),
        costMinorOf: (productId) => costs[productId],
      );

      expect(profit.salesMinor, 5000);
      expect(profit.costMinor, 2000);
    });
  });
}
