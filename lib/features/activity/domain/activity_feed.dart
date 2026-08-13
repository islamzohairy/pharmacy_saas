import '../../inventory/inventory.dart';
import '../../ledger/ledger.dart';
import 'activity_row.dart';

/// Combined feed cap (PLANS/13 §5.5) — ledger entries and manual
/// movements compete fairly for the slots by recency.
const int activityFeedCap = 100;

/// Merges the two capped feed sources into one newest-first list
/// (PLANS/13 §5.5, D10).
///
/// Manual movements (`stock_in` / `adjustment`) join the ledger entries;
/// auto `stock_out` and `initial` are filtered out — the feed shows what
/// was deliberately recorded, not what the sale flow did automatically.
/// The combined result is re-capped at [activityFeedCap] by recency.
/// Pure and testable — no provider or widget dependencies.
List<ActivityRow> mergeActivityFeed(
  List<LedgerEntry> entries,
  List<StockMovement> movements, {
  required Map<int, String> profileNames,
  required Map<int, String> productNames,
}) {
  final rows = <ActivityRow>[
    for (final entry in entries)
      LedgerActivityRow.fromEntry(entry, profileNames),
    for (final movement in movements)
      if (movement.type == StockMovementType.stockIn ||
          movement.type == StockMovementType.adjustment)
        MovementActivityRow.fromMovement(
          movement,
          profileNames,
          productNames,
        ),
  ];
  rows.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return rows.take(activityFeedCap).toList();
}