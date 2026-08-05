import '../../../core/data/tables/ledger_entry_type.dart';
import 'ledger_entry.dart';

/// The append-only financial ledger.
///
/// Deliberately minimal: the interface exposes exactly one write path —
/// [append] — and no update or delete member exists here or in any
/// implementation. A correction is a new offsetting entry; balances are
/// always computed live by aggregation over the entries these reads
/// return (ARCHITECTURE.md).
///
/// [markSynced] is sync bookkeeping only: it stamps `synced_at` on rows
/// already pushed to the backup target. It is not a financial mutation —
/// it can never alter business fields.
abstract interface class LedgerRepository {
  /// Appends one new entry. The only way a financial fact enters the
  /// ledger.
  Future<LedgerEntry> append(LedgerEntryDraft draft);

  /// Live view of entries for one pharmacy, optionally filtered by
  /// occurrence range (inclusive) and/or type, newest first. [limit]
  /// caps the number of rows when set (default `null` = unbounded —
  /// dashboard's all-time aggregation relies on that).
  Stream<List<LedgerEntry>> watchEntries({
    required int pharmacyId,
    DateTime? from,
    DateTime? to,
    LedgerEntryType? type,
    int? limit,
  });

  /// Entries referencing a specific party (supplier or customer), used
  /// to compute live balances per party.
  Stream<List<LedgerEntry>> watchEntriesByParty({
    required int pharmacyId,
    required LedgerEntryType type,
    required int partyId,
  });

  /// Rows not yet pushed to the backup target, oldest first, capped at
  /// [limit] for batched sync. [excludeIds] is a generic caller-supplied
  /// filter (the sync job passes its quarantine set) — the ledger
  /// repository never learns what a quarantine is; it only skips rows.
  Future<List<LedgerEntry>> unsyncedEntries({
    required int pharmacyId,
    int limit = 200,
    List<int> excludeIds = const [],
  });

  /// Live count of rows waiting for backup — drives the sync scheduler
  /// and the "last backed up" indicator.
  Stream<int> watchUnsyncedCount({required int pharmacyId});

  /// One-shot bounded read of the oldest row still waiting for backup
  /// (`null` when nothing is unsynced). Drives backup-staleness
  /// evaluation on scheduler state changes — deliberately a one-shot
  /// query, not a stream (PLANS/11 §4.2; the indicator must not add a
  /// new full-scan stream).
  Future<DateTime?> oldestUnsyncedAt({required int pharmacyId});

  /// Newest `synced_at` among stamped rows (`null` when nothing was ever
  /// pushed). Lets the indicator show the real last-sync time after a
  /// no-op pass / relaunch — derived from persisted sync bookkeeping,
  /// never stored as separate state (same philosophy as staleness,
  /// PLANS/11 §4.2).
  Future<DateTime?> lastSyncedAt({required int pharmacyId});

  /// Stamps `synced_at` on the given ids. Sync bookkeeping only — see
  /// the class doc. Never touches business fields.
  Future<void> markSynced({
    required int pharmacyId,
    required List<int> ids,
    required DateTime at,
  });
}
