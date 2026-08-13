import '../../../core/data/tables/stock_movement_type.dart';
import 'stock_movement.dart';

/// The append-only stock movement ledger (PLANS/12 D1).
///
/// Deliberately minimal, mirroring [LedgerRepository]: exactly one write
/// path — [recordMovement] — and no update or delete member exists here
/// or in any implementation. On-hand is never stored as a mutable
/// counter; it is always computed live by aggregation over the movements
/// these reads return.
///
/// Local-only in P0 (D5/plan §2): nothing in this interface or its
/// implementation touches the sync layer.
abstract interface class StockRepository {
  /// Appends one movement. The only way a stock fact enters the ledger.
  /// [quantity] is a signed integer delta: positive adds, negative
  /// subtracts (D4 — plain units, no fractions).
  Future<StockMovement> recordMovement({
    required int pharmacyId,
    required int productId,
    required StockMovementType type,
    required int quantity,
    required DateTime occurredAt,
    int? profileId,
    String? note,
  });

  /// Live on-hand map for every product of one pharmacy — a single
  /// grouped aggregate over the movement ledger, never per-product
  /// queries (PLANS/12 §5.2; prevents N+1 at product-list scale).
  ///
  /// Products with no movements are absent from the map (on-hand 0) —
  /// callers default missing keys to zero.
  Stream<Map<int, int>> watchAllOnHand({required int pharmacyId});

  /// Live on-hand for a single product — the same aggregation rule as
  /// [watchAllOnHand], applied per product.
  Stream<int> watchOnHand({required int pharmacyId, required int productId});

  /// Ordered movement history (oldest first) for one product — used by
  /// tests now, and by the adjustment UI in Plan 13.
  Future<List<StockMovement>> getMovements({
    required int pharmacyId,
    required int productId,
  });
}