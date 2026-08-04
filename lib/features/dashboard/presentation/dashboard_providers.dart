import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/streams/combine_latest.dart';
import '../../identity/identity.dart';
import '../../ledger/ledger.dart';
import '../../products/products.dart';
import '../domain/dashboard_range.dart';

/// A single snapshot of everything the dashboard renders, freshly derived
/// from the ledger — never cached anywhere (PLANS/07 "do not cache").
class DashboardData {
  const DashboardData({
    required this.salesMinor,
    required this.costMinor,
    required this.expensesMinor,
    required this.owedToSuppliersMinor,
    required this.owedByCustomersMinor,
    this.isEmpty = false,
  });

  /// The zero/onboarding state: the ledger has no entries at all (first
  /// day of use, PLANS/07 edge case). A range without entries while
  /// history exists elsewhere is NOT empty — it renders zeros.
  const DashboardData.empty()
    : salesMinor = 0,
      costMinor = 0,
      expensesMinor = 0,
      owedToSuppliersMinor = 0,
      owedByCustomersMinor = 0,
      isEmpty = true;

  /// Profit figures are scoped to the selected range.
  final int salesMinor;
  final int costMinor;

  /// All `expense` entries in range, regardless of category — profit is
  /// net of every expense (PLANS/10), not just owner draws.
  final int expensesMinor;

  /// Debt figures are the current all-time snapshot — they match what
  /// the plan 06 screens show (PLANS/07 decision; the balance
  /// calculators take no range).
  final int owedToSuppliersMinor;
  final int owedByCustomersMinor;

  int get netMinor => salesMinor - costMinor - expensesMinor;

  final bool isEmpty;
}

/// Selected dashboard date range — today is the default: the
/// daily-logging habit the MVP hypothesis is built to prove is the
/// first thing the owner sees (PLANS/07 builder instructions).
final dashboardRangeProvider = StateProvider<DashboardRange>(
  (ref) => DashboardRange.today,
);

/// Everything the dashboard renders, recomputed live on every ledger or
/// product change (PLANS/07 "do not cache").
///
/// Pure read screen: profit over the selected range via plan 04's
/// [calculateProfit] with COGS resolved from the live product catalog
/// (all products, deactivated included — historical sales must still
/// resolve cost), debt totals via the all-time aggregate calculators.
/// No writes occur on this screen.
///
/// The range window is NOT frozen at provider creation: `(from, to)` is
/// recomputed from `DateTime.now()` on every emission, so a sale recorded
/// on a pushed hub screen lands inside the window the moment its drift
/// stream re-emits (DECISIONS.md 2026-08-03). Entries stream all-time (the
/// same query shape the debt screens use) and the range filter runs in
/// Dart — a SQL `to` bound would go stale the instant a row was appended
/// after it, since a watch stream re-executes with its creation-time bounds.
final dashboardProvider = StreamProvider.autoDispose<DashboardData>((ref) {
  final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
  if (pharmacyId == null) return Stream.value(const DashboardData.empty());
  final repository = ref.watch(ledgerRepositoryProvider);
  final range = ref.watch(dashboardRangeProvider);
  return combineLatest2(
    // All-time entries for the range-scoped profit, the all-time debt
    // totals and the empty-state check — served by the (pharmacy_id,
    // occurred_at) index's tenant prefix.
    repository.watchEntries(pharmacyId: pharmacyId),
    ref.watch(productRepositoryProvider).watchAll(pharmacyId: pharmacyId),
  ).map((parts) {
    final (allEntries, products) = parts;
    if (allEntries.isEmpty) return const DashboardData.empty();
    final (from, to) = rangeOf(range, DateTime.now());
    final rangeEntries = allEntries
        .where((e) => !e.occurredAt.isBefore(from) && !e.occurredAt.isAfter(to))
        .toList();
    final costs = {
      for (final product in products) product.id: product.costMinor,
    };
    final profit = calculateProfit(
      entries: rangeEntries,
      from: from,
      to: to,
      costMinorOf: (productId) => costs[productId],
    );
    return DashboardData(
      salesMinor: profit.salesMinor,
      costMinor: profit.costMinor,
      expensesMinor: profit.expensesMinor,
      owedToSuppliersMinor: calculateTotalOwedToSuppliers(entries: allEntries),
      owedByCustomersMinor: calculateTotalOwedByCustomers(entries: allEntries),
    );
  });
});
