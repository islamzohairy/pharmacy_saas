import 'package:drift/drift.dart' hide isNull;

import '../../../core/data/app_database.dart';
import '../../../core/data/tables/stock_movement_type.dart';
import '../domain/on_hand_reducer.dart';
import '../domain/stock_movement.dart';
import '../domain/stock_repository.dart';

/// [StockRepository] backed by the local drift database.
///
/// Local-only by plan scope: nothing here touches the sync layer — stock
/// movements never leave the device in P0 (PLANS/12 §2).
class DriftStockRepository implements StockRepository {
  DriftStockRepository(this._db);

  final AppDatabase _db;

  @override
  Future<StockMovement> recordMovement({
    required int pharmacyId,
    required int productId,
    required StockMovementType type,
    required int quantity,
    required DateTime occurredAt,
    int? profileId,
    String? note,
  }) {
    return _db
        .into(_db.stockMovements)
        .insertReturning(
          StockMovementsCompanion.insert(
            pharmacyId: pharmacyId,
            productId: productId,
            type: type,
            quantity: quantity,
            occurredAt: occurredAt,
            profileId: Value(profileId),
            note: Value(note),
          ),
        )
        .then(_toDomain);
  }

  @override
  Stream<Map<int, int>> watchAllOnHand({required int pharmacyId}) {
    // One grouped aggregate over the movement ledger — never per-product
    // queries (PLANS/12 §5.2; the N+1 trap the plan calls out).
    final query = _db.selectOnly(_db.stockMovements)
      ..addColumns([
        _db.stockMovements.productId,
        _db.stockMovements.quantity.sum(),
      ])
      ..where(_db.stockMovements.pharmacyId.equals(pharmacyId))
      ..groupBy([_db.stockMovements.productId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.stockMovements.productId)!:
              row.read(_db.stockMovements.quantity.sum()) ?? 0,
      },
    );
  }

  @override
  Future<Map<int, int>> allOnHand({required int pharmacyId}) async {
    // One-shot twin of watchAllOnHand: same query, same map-key semantics
    // (absence = not tracked), no stream machinery — fake-async-safe for
    // the sales confirm-time read (PLANS/13 §5.2).
    final query = _db.selectOnly(_db.stockMovements)
      ..addColumns([
        _db.stockMovements.productId,
        _db.stockMovements.quantity.sum(),
      ])
      ..where(_db.stockMovements.pharmacyId.equals(pharmacyId))
      ..groupBy([_db.stockMovements.productId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(_db.stockMovements.productId)!:
            row.read(_db.stockMovements.quantity.sum()) ?? 0,
    };
  }

  @override
  Stream<int> watchOnHand({
    required int pharmacyId,
    required int productId,
  }) {
    // Same aggregation rule as watchAllOnHand, applied per product via
    // the shared pure reducer over the movement stream.
    final query = _db.select(_db.stockMovements)
      ..where(
        (t) =>
            t.pharmacyId.equals(pharmacyId) &
            t.productId.equals(productId),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return query
        .watch()
        .map((rows) => reduceOnHand(rows.map(_toDomain)));
  }

  @override
  Future<List<StockMovement>> getMovements({
    required int pharmacyId,
    required int productId,
  }) {
    final query = _db.select(_db.stockMovements)
      ..where(
        (t) =>
            t.pharmacyId.equals(pharmacyId) &
            t.productId.equals(productId),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return query.get().then((rows) => rows.map(_toDomain).toList());
  }

  StockMovement _toDomain(StoredStockMovement row) => StockMovement(
    id: row.id,
    pharmacyId: row.pharmacyId,
    productId: row.productId,
    type: row.type,
    quantity: row.quantity,
    occurredAt: row.occurredAt,
    profileId: row.profileId,
    note: row.note,
  );
}