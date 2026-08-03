import 'package:drift/drift.dart';

/// Local crash/error capture log (PLANS/09).
///
/// LOCAL-ONLY by decision — like products/suppliers/customers, this never
/// rides the ledger sync path (the server surface has RPCs for ledger
/// entries only, and diagnostics are deliberately kept off it).
///
/// `reportedAt` is set ONLY by the dashboard indicator's explicit
/// "reported/dismissed" action; rows with NULL count toward the
/// unreported indicator. Opening the dashboard never touches this column,
/// so a crash cannot silently disappear from visibility.
///
/// Stack traces are truncated at write time (see `ErrorLogRepository`) to
/// stay inside the column length limits.
@DataClassName('StoredErrorLogEntry')
class ErrorLogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get errorType => text().withLength(min: 1, max: 128)();
  TextColumn get message => text().withLength(min: 1, max: 2048)();
  TextColumn get stackTrace =>
      text().withLength(min: 1, max: 8192).nullable()();
  DateTimeColumn get reportedAt => dateTime().nullable()();
}
