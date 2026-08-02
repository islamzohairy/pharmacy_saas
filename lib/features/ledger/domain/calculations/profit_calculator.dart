import '../../../../core/data/tables/ledger_entry_type.dart';
import '../ledger_entry.dart';

/// The components of profit over a range, and the derived net figure.
///
/// Plan 07's dashboard renders each line separately, so the calculator
/// returns the breakdown, not just a single number.
class ProfitBreakdown {
  const ProfitBreakdown({
    required this.salesMinor,
    required this.costMinor,
    required this.drawsMinor,
  });

  /// Sum of `sale` entry amounts.
  final int salesMinor;

  /// Sum of cost of goods sold, read from each sold product's `cost_minor`
  /// at calculation time (PLANS/05 — never stored in the ledger row).
  final int costMinor;

  /// Sum of `cashDraw` entry amounts.
  final int drawsMinor;

  /// sales − cost − draws.
  int get netMinor => salesMinor - costMinor - drawsMinor;
}

/// Profit = sum(sale amounts) − sum(cost of goods sold) − sum(cash draws),
/// over [from]..[to] (inclusive, matching the repository's range query).
///
/// Pure function over [entries] — no database access. Cost is resolved
/// through [costMinorOf] so this layer never imports drift or products
/// code (PLANS/04, PLANS/05); a sale whose product has no resolvable cost
/// counts as zero cost. Debt entries never affect profit.
ProfitBreakdown calculateProfit({
  required List<LedgerEntry> entries,
  DateTime? from,
  DateTime? to,
  required int? Function(int productId) costMinorOf,
}) {
  var salesMinor = 0;
  var costMinor = 0;
  var drawsMinor = 0;

  for (final entry in entries) {
    if (!_inRange(entry.occurredAt, from, to)) continue;
    switch (entry.type) {
      case LedgerEntryType.sale:
        salesMinor += entry.amountMinor;
        final productId = entry.productId;
        if (productId != null) {
          costMinor += costMinorOf(productId) ?? 0;
        }
      case LedgerEntryType.cashDraw:
        drawsMinor += entry.amountMinor;
      case LedgerEntryType.supplierDebt:
      case LedgerEntryType.customerDebt:
      case LedgerEntryType.debtRepayment:
        break;
    }
  }

  return ProfitBreakdown(
    salesMinor: salesMinor,
    costMinor: costMinor,
    drawsMinor: drawsMinor,
  );
}

bool _inRange(DateTime occurredAt, DateTime? from, DateTime? to) {
  if (from != null && occurredAt.isBefore(from)) return false;
  if (to != null && occurredAt.isAfter(to)) return false;
  return true;
}
