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

  /// One-shot snapshot of [watchAllOnHand] — the same aggregation and the
  /// same map-key semantics (absence = not tracked), as a plain future.
  ///
  /// Streams from drift schedule zero-duration timers and can't complete
  /// under a widget test's fake-async zone; the confirm-time reads in the
  /// sales flow use this instead of `watchAllOnHand(...).first` (PLANS/13
  /// §5.2 staff review item: fresh read at confirm, live stream not needed).
  Future<Map<int, int>> allOnHand({required int pharmacyId});

  /// Live on-hand for a single product — the same aggregation rule as
  /// [watchAllOnHand], applied per product.
  ///
  /// Note: tracked-vs-zero is deliberately NOT distinguished here — an
  /// empty history reduces to 0. The distinction belongs to the
  /// aggregate map (absence = not tracked) and its callers; a future
  /// single-product consumer (Plan 13 adjustment UI) must inherit the
  /// absence signal instead of re-introducing `?? 0` (DECISIONS.md
  /// 2026-08-13).
  Stream<int> watchOnHand({required int pharmacyId, required int productId});

  /// Ordered movement history (oldest first) for one product — used by
  /// tests now, and by the adjustment UI in Plan 13.
  Future<List<StockMovement>> getMovements({
    required int pharmacyId,
    required int productId,
  });
}