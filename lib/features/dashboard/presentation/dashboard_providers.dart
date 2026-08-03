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
    required this.drawsMinor,
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
      drawsMinor = 0,
      owedToSuppliersMinor = 0,
      owedByCustomersMinor = 0,
      isEmpty = true;

  /// Profit figures are scoped to the selected range.
  final int salesMinor;
  final int costMinor;
  final int drawsMinor;

  /// Debt figures are the current all-time snapshot — they match what
  /// the plan 06 screens show (PLANS/07 decision; the balance
  /// calculators take no range).
  final int owedToSuppliersMinor;
  final int owedByCustomersMinor;

  int get netMinor => salesMinor - costMinor - drawsMinor;

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
final dashboardProvider = StreamProvider.autoDispose<DashboardData>((ref) {
  final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
  if (pharmacyId == null) return Stream.value(const DashboardData.empty());
  final repository = ref.watch(ledgerRepositoryProvider);
  final (from, to) = rangeOf(ref.watch(dashboardRangeProvider), DateTime.now());
  return combineLatest3(
    // Range-scoped entries for the profit breakdown — bounded by the
    // plan 03 `(pharmacy_id, occurred_at)` index (PLANS/07 performance).
    repository.watchEntries(pharmacyId: pharmacyId, from: from, to: to),
    // All-time entries for the debt totals and the empty-state check.
    repository.watchEntries(pharmacyId: pharmacyId),
    ref.watch(productRepositoryProvider).watchAll(pharmacyId: pharmacyId),
  ).map((parts) {
    final (rangeEntries, allEntries, products) = parts;
    if (allEntries.isEmpty) return const DashboardData.empty();
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
      drawsMinor: profit.drawsMinor,
      owedToSuppliersMinor: calculateTotalOwedToSuppliers(entries: allEntries),
      owedByCustomersMinor: calculateTotalOwedByCustomers(entries: allEntries),
    );
  });
});
