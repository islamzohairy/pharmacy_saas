import 'package:drift/drift.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/tables/ledger_entry_type.dart';
import '../domain/ledger_entry.dart';
import '../domain/ledger_repository.dart';

/// [LedgerRepository] backed by the local drift database — the local
/// store is always the source of truth for reads (ARCHITECTURE.md).
///
/// The append-only property is structural: this class only ever runs
/// INSERTs on `ledger_entries` plus the sync bookkeeping UPDATE of
/// `synced_at`. No other drift write API on this table is reachable from
/// this feature (or anywhere else in the codebase).
class DriftLedgerRepository implements LedgerRepository {
  DriftLedgerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<LedgerEntry> append(LedgerEntryDraft draft) {
    return _db.transaction(() async {
      final row = await _db
          .into(_db.ledgerEntries)
          .insertReturning(
            LedgerEntriesCompanion.insert(
              pharmacyId: draft.pharmacyId,
              type: draft.type,
              amountMinor: draft.amountMinor,
              productId: Value(draft.productId),
              supplierId: Value(draft.supplierId),
              customerId: Value(draft.customerId),
              profileId: Value(draft.profileId),
              category: Value(draft.category),
              occurredAt: draft.occurredAt,
              note: Value(draft.note),
            ),
          );
      return _toDomain(row);
    });
  }

  @override
  Stream<List<LedgerEntry>> watchEntries({
    required int pharmacyId,
    DateTime? from,
    DateTime? to,
    LedgerEntryType? type,
    int? limit,
  }) {
    final query = _db.select(_db.ledgerEntries)
      ..where((t) {
        var condition = t.pharmacyId.equals(pharmacyId);
        if (from != null) {
          condition = condition & t.occurredAt.isBiggerOrEqualValue(from);
        }
        if (to != null) {
          condition = condition & t.occurredAt.isSmallerOrEqualValue(to);
        }
        if (type != null) {
          condition = condition & t.type.equals(type.name);
        }
        return condition;
      })
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<LedgerEntry>> watchEntriesByParty({
    required int pharmacyId,
    required LedgerEntryType type,
    required int partyId,
  }) {
    final query = _db.select(_db.ledgerEntries)
      ..where((t) {
        var condition = t.pharmacyId.equals(pharmacyId);
        condition = condition & t.type.equals(type.name);
        condition =
            condition &
            (type == LedgerEntryType.supplierDebt ||
                    type == LedgerEntryType.debtRepayment
                ? t.supplierId.equals(partyId)
                : t.customerId.equals(partyId));
        return condition;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<LedgerEntry>> unsyncedEntries({
    required int pharmacyId,
    int limit = 200,
  }) {
    final query = _db.select(_db.ledgerEntries)
      ..where((t) => t.pharmacyId.equals(pharmacyId) & t.syncedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.id)])
      ..limit(limit);
    return query.get().then((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<int> watchUnsyncedCount({required int pharmacyId}) {
    final count = _db.ledgerEntries.id.count();
    return (_db.selectOnly(_db.ledgerEntries)
          ..addColumns([count])
          ..where(
            _db.ledgerEntries.pharmacyId.equals(pharmacyId) &
                _db.ledgerEntries.syncedAt.isNull(),
          ))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  @override
  Future<void> markSynced({
    required int pharmacyId,
    required List<int> ids,
    required DateTime at,
  }) {
    if (ids.isEmpty) return Future.value();
    return _db.transaction(() async {
      for (final id in ids) {
        await (_db.update(_db.ledgerEntries)
              ..where((t) => t.id.equals(id) & t.pharmacyId.equals(pharmacyId)))
            .write(LedgerEntriesCompanion(syncedAt: Value(at)));
      }
    });
  }

  LedgerEntry _toDomain(StoredLedgerEntry row) => LedgerEntry(
    id: row.id,
    pharmacyId: row.pharmacyId,
    type: row.type,
    amountMinor: row.amountMinor,
    productId: row.productId,
    supplierId: row.supplierId,
    customerId: row.customerId,
    profileId: row.profileId,
    category: row.category,
    occurredAt: row.occurredAt,
    note: row.note,
    syncedAt: row.syncedAt,
  );
}
