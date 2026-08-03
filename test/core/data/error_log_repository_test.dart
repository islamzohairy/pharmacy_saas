import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/error_log_repository.dart';

import '../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late ErrorLogRepository repository;

  setUp(() async {
    db = await createMemoryDb();
    repository = ErrorLogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('record appends and the unreported count increments', () async {
    expect(await repository.watchUnreportedCount().first, 0);

    await repository.record(errorType: 'StateError', message: 'boom');
    expect(await repository.watchUnreportedCount().first, 1);

    await repository.record(
      errorType: 'TypeError',
      message: 'late error',
      stackTrace: 'trace line 1',
    );
    expect(await repository.watchUnreportedCount().first, 2);
  });

  test('markAllReported clears the count but keeps the rows', () async {
    await repository.record(errorType: 'StateError', message: 'boom');

    await repository.markAllReported();

    expect(await repository.watchUnreportedCount().first, 0);
    expect(await repository.unreportedEntries(), isEmpty);
  });

  test('long message and stack are truncated inside the column limits', () async {
    await repository.record(
      errorType: 'StateError',
      message: 'm' * 5000,
      stackTrace: 's' * 30000,
    );

    final rows = await db.select(db.errorLogEntries).get();
    expect(rows.single.message.length, lessThanOrEqualTo(1900));
    expect(rows.single.stackTrace!.length, lessThanOrEqualTo(8000));
  });

  test('unreportedEntries returns newest first', () async {
    await repository.record(errorType: 'A', message: 'first');
    await repository.record(errorType: 'B', message: 'second');

    final entries = await repository.unreportedEntries();
    expect(entries.first.message, 'second');
    expect(entries.last.message, 'first');
  });
}