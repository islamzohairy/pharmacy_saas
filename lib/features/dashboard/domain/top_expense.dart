import '../../ledger/ledger.dart';

/// The highest-expense-category insight (PLANS/14 §5.4, D16): the
/// expense category with the largest total in the selected range, with
/// its amount and share of the range's total expenses.
///
/// Pure domain function — no drift, no providers — so the rule is
/// trivially testable. Guarantees, all unit-tested:
/// - only `expense` entries inside [from, to] contribute;
/// - uncategorized expense rows count under [ExpenseCategory.other];
/// - ties break deterministically: largest total, then category
///   declaration order (D16) — no dependence on iteration order;
/// - an empty range yields `null` — the insight hides, it never shows a
///   zero (D16, low-information-density principle).
class TopExpense {
  const TopExpense({
    required this.category,
    required this.amountMinor,
    required this.sharePercent,
  });

  final ExpenseCategory category;
  final int amountMinor;

  /// Rounded integer percent of the range's total expenses.
  final int sharePercent;
}

TopExpense? topExpenseInRange(
  Iterable<LedgerEntry> entries, {
  required DateTime from,
  required DateTime to,
}) {
  final totals = <ExpenseCategory, int>{};
  for (final entry in entries) {
    if (entry.type != LedgerEntryType.expense) continue;
    if (entry.occurredAt.isBefore(from) || entry.occurredAt.isAfter(to)) {
      continue;
    }
    final category = entry.category ?? ExpenseCategory.other;
    totals[category] = (totals[category] ?? 0) + entry.amountMinor;
  }
  if (totals.isEmpty) return null;

  ExpenseCategory best = totals.keys.first;
  for (final entry in totals.entries) {
    final current = totals[best]!;
    final isStrictlyLarger = entry.value > current;
    final isTieWithEarlierOrder =
        entry.value == current && entry.key.index < best.index;
    if (isStrictlyLarger || isTieWithEarlierOrder) best = entry.key;
  }
  final total = totals.values.fold(0, (sum, value) => sum + value);
  return TopExpense(
    category: best,
    amountMinor: totals[best]!,
    sharePercent: ((totals[best]! * 100) / total).round(),
  );
}