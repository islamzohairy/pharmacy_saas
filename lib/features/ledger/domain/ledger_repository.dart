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
  /// occurrence range (inclusive) and/or type.
  Stream<List<LedgerEntry>> watchEntries({
    required int pharmacyId,
    DateTime? from,
    DateTime? to,
    LedgerEntryType? type,
  });

  /// Entries referencing a specific party (supplier or customer), used
  /// to compute live balances per party.
  Stream<List<LedgerEntry>> watchEntriesByParty({
    required int pharmacyId,
    required LedgerEntryType type,
    required int partyId,
  });

  /// Rows not yet pushed to the backup target, oldest first, capped at
  /// [limit] for batched sync.
  Future<List<LedgerEntry>> unsyncedEntries({
    required int pharmacyId,
    int limit = 200,
  });

  /// Live count of rows waiting for backup — drives the sync scheduler
  /// and the "last backed up" indicator.
  Stream<int> watchUnsyncedCount({required int pharmacyId});

  /// Stamps `synced_at` on the given ids. Sync bookkeeping only — see
  /// the class doc. Never touches business fields.
  Future<void> markSynced({
    required int pharmacyId,
    required List<int> ids,
    required DateTime at,
  });
}
