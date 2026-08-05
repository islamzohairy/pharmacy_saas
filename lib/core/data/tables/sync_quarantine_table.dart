import 'package:drift/drift.dart';

/// Local record of ledger entries permanently rejected by the backup
/// target (PLANS/11-H Phase 2).
///
/// A push that fails with one of the ruled permanent SQLSTATE codes
/// ({23514, 23503, 23502, 22P02}) quarantines the batch here instead of
/// retrying it forever. Quarantine is sync bookkeeping only — it NEVER
/// touches `ledger_entries`: rows stay `synced_at NULL` (so staleness
/// still counts them) and are excluded from push candidates by the sync
/// job. There is no auto-release path; visibility is the error log and the
/// staleness indicator (ruled 2026-08-05).
///
/// `message` is truncated at write time (see `QuarantineRepository`) to
/// stay inside the column length limit.
@DataClassName('StoredSyncQuarantineEntry')
class SyncQuarantineEntries extends Table {
  IntColumn get pharmacyId => integer()();
  IntColumn get entryId => integer()();

  /// SQLSTATE of the permanent failure (e.g. '23503').
  TextColumn get code => text().withLength(min: 1, max: 16)();

  TextColumn get message => text().withLength(min: 1, max: 2048).nullable()();
  DateTimeColumn get quarantinedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {pharmacyId, entryId};
}
