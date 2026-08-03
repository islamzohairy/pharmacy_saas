import 'package:drift/drift.dart';

import 'app_database.dart';

const _messageLimit = 1900;
const _stackLimit = 8000;
const _typeLimit = 128;

/// Writes and queries the local crash/error log (PLANS/09).
///
/// LOCAL-ONLY: like products/suppliers/customers, this never participates
/// in the ledger sync path. `reportedAt` is set ONLY by the explicit
/// "reported/dismissed" action on the dashboard indicator — opening the
/// dashboard never clears a crash from visibility.
///
/// Writer failures are the caller's problem only where the caller chooses;
/// the capture layer swallows errors so a logging bug can't take the app
/// down.
class ErrorLogRepository {
  const ErrorLogRepository(this._db);

  final AppDatabase _db;

  /// Appends one error. Long values are truncated defensively so they can
  /// never violate the column length constraints.
  Future<void> record({
    required String errorType,
    required String message,
    String? stackTrace,
  }) async {
    final type =
        errorType.length > _typeLimit
            ? errorType.substring(0, _typeLimit)
            : errorType;
    final msg =
        message.length > _messageLimit
            ? message.substring(0, _messageLimit)
            : message;
    final stack =
        stackTrace == null
            ? null
            : (stackTrace.length > _stackLimit
                  ? stackTrace.substring(0, _stackLimit)
                  : stackTrace);

    await _db.into(_db.errorLogEntries).insert(
          ErrorLogEntriesCompanion.insert(
            occurredAt: DateTime.now(),
            errorType: type,
            message: msg,
            stackTrace: Value(stack),
          ),
        );
  }

  /// Live count of entries still awaiting report — the indicator's number.
  Stream<int> watchUnreportedCount() {
    final query =
        _db.selectOnly(_db.errorLogEntries)
          ..addColumns([_db.errorLogEntries.id.count()])
          ..where(_db.errorLogEntries.reportedAt.isNull());
    return query.watch().map(
      (rows) => rows.first.read(_db.errorLogEntries.id.count()) ?? 0,
    );
  }

  /// Newest-first entries awaiting report — the export source for the
  /// indicator dialog.
  Future<List<StoredErrorLogEntry>> unreportedEntries() {
    return (_db.select(_db.errorLogEntries)
          ..where((t) => t.reportedAt.isNull())
          ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.id),
      ]))
        .get();
  }

  /// The indicator's explicit "reported/dismissed" action — the only thing
  /// that clears the unreported count.
  Future<void> markAllReported() async {
    await (_db.update(_db.errorLogEntries)
          ..where((t) => t.reportedAt.isNull()))
        .write(ErrorLogEntriesCompanion(reportedAt: Value(DateTime.now())));
  }
}