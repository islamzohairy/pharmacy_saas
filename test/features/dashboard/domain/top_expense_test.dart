import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/expense_category.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/dashboard/domain/top_expense.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';

/// D16 matrix (PLANS/14 §7): the insight follows the selected range,
/// hides entirely when the range has no expenses, and breaks ties
/// deterministically (largest total, then category declaration order).
void main() {
  LedgerEntry expense({
    int amountMinor = 1000,
    ExpenseCategory category = ExpenseCategory.rent,
    DateTime? occurredAt,
  }) {
    return LedgerEntry(
      id: 0,
      pharmacyId: 0,
      type: LedgerEntryType.expense,
      amountMinor: amountMinor,
      category: category,
      occurredAt: occurredAt ?? DateTime(2026, 8, 5, 10),
      syncedAt: null,
    );
  }

  final from = DateTime(2026, 8, 1);
  final to = DateTime(2026, 8, 31, 23, 59);

  test('returns the category with the largest total in range', () {
    final result = topExpenseInRange(
      [
        expense(category: ExpenseCategory.rent, amountMinor: 500),
        expense(category: ExpenseCategory.supplies, amountMinor: 900),
        expense(category: ExpenseCategory.ownerDraw, amountMinor: 200),
      ],
      from: from,
      to: to,
    );
    expect(result, isNotNull);
    expect(result!.category, ExpenseCategory.supplies);
    expect(result.amountMinor, 900);
  });

  test('aggregates multiple entries of the same category', () {
    final result = topExpenseInRange(
      [
        expense(category: ExpenseCategory.rent, amountMinor: 300),
        expense(category: ExpenseCategory.rent, amountMinor: 400),
        expense(category: ExpenseCategory.utilities, amountMinor: 500),
      ],
      from: from,
      to: to,
    );
    expect(result!.category, ExpenseCategory.rent);
    expect(result.amountMinor, 700);
  });

  test('ties break by category declaration order (D16)', () {
    final result = topExpenseInRange(
      [
        expense(category: ExpenseCategory.other, amountMinor: 500),
        expense(category: ExpenseCategory.rent, amountMinor: 500),
      ],
      from: from,
      to: to,
    );
    // ownerDraw < rent < utilities < supplies < other — declaration
    // order is the deterministic tie-breaker (D16).
    expect(result!.category, ExpenseCategory.rent);
  });

  test('share of the range total is a rounded integer percent', () {
    final result = topExpenseInRange(
      [
        expense(category: ExpenseCategory.rent, amountMinor: 200),
        expense(category: ExpenseCategory.rent, amountMinor: 200),
        expense(category: ExpenseCategory.supplies, amountMinor: 500),
      ],
      from: from,
      to: to,
    );
    expect(result!.category, ExpenseCategory.supplies);
    // 500 of 900 → 55.55% → rounds to 56.
    expect(result.sharePercent, 56);
  });

  test('entries outside the range are excluded', () {
    final result = topExpenseInRange(
      [
        expense(occurredAt: DateTime(2026, 7, 31, 23), amountMinor: 9000),
        expense(occurredAt: DateTime(2026, 8, 15), amountMinor: 30),
        expense(occurredAt: DateTime(2026, 9, 1), amountMinor: 9000),
      ],
      from: from,
      to: to,
    );
    expect(result!.category, ExpenseCategory.rent);
    expect(result.amountMinor, 30);
  });

  test('non-expense entries never contribute', () {
    final result = topExpenseInRange(
      [
        LedgerEntry(
          id: 1,
          pharmacyId: 0,
          type: LedgerEntryType.sale,
          amountMinor: 999999,
          occurredAt: DateTime(2026, 8, 10),
          syncedAt: null,
        ),
      ],
      from: from,
      to: to,
    );
    expect(result, isNull);
  });

  test('empty range yields no insight (hidden, not noise — D16)', () {
    final result = topExpenseInRange(const [], from: from, to: to);
    expect(result, isNull);
  });

  test('an uncategorized expense counts under "other"', () {
    final result = topExpenseInRange(
      [
        expense(category: ExpenseCategory.rent, amountMinor: 100),
        LedgerEntry(
          id: 2,
          pharmacyId: 0,
          type: LedgerEntryType.expense,
          amountMinor: 400,
          category: null,
          occurredAt: DateTime(2026, 8, 10),
          syncedAt: null,
        ),
      ],
      from: from,
      to: to,
    );
    expect(result!.category, ExpenseCategory.other);
    expect(result.amountMinor, 400);
  });
}