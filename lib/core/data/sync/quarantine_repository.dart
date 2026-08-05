import 'package:drift/drift.dart';

import '../app_database.dart';

const _messageLimit = 1900;

/// Writes and reads the sync-failure quarantine (PLANS/11-H Phase 2).
///
/// Quarantine is sync bookkeeping only: it records which local ledger
/// entries the backup target permanently rejected. It never touches
/// `ledger_entries` — rows stay `synced_at NULL` (staleness still counts
/// them) and are merely excluded from push candidates by the sync job.
/// There is no release path; the error log and the staleness indicator
/// are the visibility.
class QuarantineRepository {
  const QuarantineRepository(this._db);

  final AppDatabase _db;

  /// Records one quarantine event: the batch's entry ids plus a single
  /// human-readable reason. Idempotent per (pharmacy, entry) — a crash
  /// mid-pass can safely re-quarantine the same batch.
  Future<void> quarantine({
    required int pharmacyId,
    required List<int> entryIds,
    required String code,
    String? message,
  }) async {
    if (entryIds.isEmpty) return;
    final msg =
        message == null
            ? null
            : (message.length > _messageLimit
                  ? message.substring(0, _messageLimit)
                  : message);
    await _db.transaction(() async {
      for (final id in entryIds) {
        await _db.into(_db.syncQuarantineEntries).insert(
              SyncQuarantineEntriesCompanion.insert(
                pharmacyId: pharmacyId,
                entryId: id,
                code: code,
                message: Value(msg),
                quarantinedAt: DateTime.now(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  /// All quarantined entry ids for the pharmacy — the push-candidate
  /// exclusion set.
  Future<Set<int>> quarantinedEntryIds({required int pharmacyId}) async {
    final rows = await (_db.select(_db.syncQuarantineEntries)
          ..where((t) => t.pharmacyId.equals(pharmacyId)))
        .get();
    return rows.map((r) => r.entryId).toSet();
  }
}
