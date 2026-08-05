import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/error_log_repository.dart';
import 'package:pharmacy_saas/core/data/sync/quarantine_repository.dart';
import 'package:pharmacy_saas/core/data/sync/remote_backup_client.dart';
import 'package:pharmacy_saas/core/data/sync/sync_job.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/ledger/data/ledger_repository_impl.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/helpers.dart';

class FakeRemoteBackupClient implements RemoteBackupClient {
  FakeRemoteBackupClient({this.configured = true});

  bool configured;
  bool failNextPush = false;
  bool failAllPushes = false;
  Object? pushError;
  int registerCalls = 0;
  int pushCalls = 0;
  final List<List<RemoteLedgerEntry>> pushedBatches = [];

  @override
  bool get isConfigured => configured;

  @override
  Future<void> registerDevice({
    required String deviceToken,
    required String pharmacyUuid,
    required String pharmacyName,
    required String currency,
  }) async {
    registerCalls++;
  }

  @override
  Future<int> pushLedgerEntries({
    required String deviceToken,
    required List<RemoteLedgerEntry> entries,
  }) async {
    pushCalls++;
    if (failAllPushes || failNextPush) {
      failNextPush = false;
      throw pushError ?? Exception('push failed');
    }
    pushedBatches.add(entries);
    return entries.length;
  }
}

void main() {
  late AppDatabase db;
  late DriftLedgerRepository ledger;
  late QuarantineRepository quarantine;
  late ErrorLogRepository errorLog;
  late FakeRemoteBackupClient client;
  late SyncJob job;
  late int pharmacyId;
  late int profileId;

  const credentials = SyncCredentials(
    deviceToken: 'token',
    deviceRegistered: true,
    pharmacyUuid: 'uuid',
    pharmacyName: 'صيدلية',
    currency: 'EGP',
  );

  setUp(() async {
    db = await createMemoryDb();
    ledger = DriftLedgerRepository(db);
    quarantine = QuarantineRepository(db);
    errorLog = ErrorLogRepository(db);
    client = FakeRemoteBackupClient();
    job = SyncJob(
      ledgerRepository: ledger,
      client: client,
      quarantineRepository: quarantine,
      errorLogRepository: errorLog,
    );
    pharmacyId = await seedPharmacy(db);
    profileId = await seedProfile(db, pharmacyId);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> appendEntry({int amount = 100}) {
    return ledger
        .append(
          LedgerEntryDraft(
            pharmacyId: pharmacyId,
            type: LedgerEntryType.expense,
            amountMinor: amount,
            occurredAt: DateTime(2026, 8, 2, 10),
            profileId: profileId,
          ),
        )
        .then((e) => e.id);
  }

  test('skipped entirely when no backend is configured', () async {
    client.configured = false;
    await appendEntry();

    final result = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );

    expect(result.isSkipped, isTrue);
    expect(client.pushCalls, 0);
    expect(client.registerCalls, 0);
    expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), hasLength(1));
  });

  test('registers once then pushes and stamps synced rows', () async {
    final id = await appendEntry();

    var onRegistered = 0;
    final result = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
      onRegistered: () async => onRegistered++,
    );

    expect(result.isSuccess, isTrue);
    expect(result.pushed, 1);
    expect(client.pushCalls, 1);
    expect(client.pushedBatches.single.single.id, id);
    expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), isEmpty);

    // Second pass: nothing left to push.
    final second = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );
    expect(second.isSuccess, isTrue);
    expect(second.pushed, 0);
    expect(client.pushCalls, 1);
  });

  test(
    'unregistered device calls registerDevice exactly once per run',
    () async {
      await appendEntry();
      var registeredCalls = 0;
      const unregistered = SyncCredentials(
        deviceToken: 'token',
        deviceRegistered: false,
        pharmacyUuid: 'uuid',
        pharmacyName: 'صيدلية',
        currency: 'EGP',
      );

      final result = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: unregistered,
        onRegistered: () async => registeredCalls++,
      );

      expect(result.isSuccess, isTrue);
      expect(client.registerCalls, 1);
      expect(registeredCalls, 1);
    },
  );

  test('failed push returns failure with exponential backoff', () async {
    await appendEntry();

    client.failAllPushes = true;
    final first = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );
    final second = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );

    expect(first.isSuccess, isFalse);
    expect(first.suggestedRetryDelay, const Duration(seconds: 5));
    expect(second.suggestedRetryDelay, const Duration(seconds: 10));
    expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), hasLength(1));
  });

  test('backoff resets after a success', () async {
    await appendEntry();

    client.failNextPush = true;
    final failed = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );
    expect(failed.isSuccess, isFalse);
    expect(failed.suggestedRetryDelay, const Duration(seconds: 5));

    final success = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );
    expect(success.isSuccess, isTrue);

    await appendEntry();
    client.failNextPush = true;
    final failedAgain = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );
    expect(failedAgain.suggestedRetryDelay, const Duration(seconds: 5));
  });

  test(
    'batch failure mid-sync: nothing stamped, retry re-pushes all',
    () async {
      final ids = <int>[];
      for (var i = 0; i < 5; i++) {
        ids.add(await appendEntry(amount: 100 + i));
      }

      // Fail on the second batch (batch size 200 is larger than 5 entries,
      // so simulate failure on the first push instead).
      client.failNextPush = true;
      final result = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );

      expect(result.isSuccess, isFalse);
      expect(
        await ledger.unsyncedEntries(pharmacyId: pharmacyId),
        hasLength(5),
      );

      final retry = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );
      expect(retry.isSuccess, isTrue);
      expect(retry.pushed, 5);
      // The retry pushed the full batch again (server-side upsert is
      // idempotent — see the migration), and nothing was double-stamped.
      expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), isEmpty);
    },
  );

  test(
    'server-side idempotency assumption: same ids re-pushed on retry',
    () async {
      final id = await appendEntry();

      client.failNextPush = true;
      await job.runOnce(pharmacyId: pharmacyId, credentials: credentials);

      final retry = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );
      expect(retry.pushed, 1);
      expect(client.pushedBatches.single.single.id, id);
    },
  );

  Future<void> appendMany(int count) async {
    for (var i = 0; i < count; i++) {
      await appendEntry(amount: 100 + i);
    }
  }

  List<int> pushedIds() =>
      client.pushedBatches.expand((b) => b.map((e) => e.id)).toList();

  test(
    'STALL BOUNDARY (staff-review addition 1): a quarantined first batch '
    'must not block entries after it — they are pushed in the same pass',
    () async {
      await appendMany(250);
      // Quarantine the entire first batch (ids 1..200 of 250).
      final all = await ledger.unsyncedEntries(
        pharmacyId: pharmacyId,
        limit: 250,
      );
      final firstBatch = all.sublist(0, 200);
      final after = all.sublist(200);
      await quarantine.quarantine(
        pharmacyId: pharmacyId,
        entryIds: firstBatch.map((e) => e.id).toList(),
        code: '23503',
        message: 'Key (product_id)=(1) is not present in table "products"',
      );

      final result = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );

      expect(result.isSuccess, isTrue);
      // The 50 entries AFTER the quarantined span were pushed this pass.
      expect(result.pushed, 50);
      expect(pushedIds().toSet(), after.map((e) => e.id).toSet());
      // No quarantined id was ever pushed.
      expect(pushedIds().where(firstBatch.map((e) => e.id).contains), isEmpty);
      // Quarantined rows stay unsynced (still counted by staleness).
      expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), hasLength(200));
    },
  );

  test(
    'quarantined entries straddling a batch boundary are skipped while '
    'entries on both sides are pushed in the same pass',
    () async {
      await appendMany(250);
      final all = await ledger.unsyncedEntries(
        pharmacyId: pharmacyId,
        limit: 250,
      );
      final straddle = all.sublist(99, 249);
      final expectedPushed = {
        ...all.sublist(0, 99).map((e) => e.id),
        all[249].id,
      };
      await quarantine.quarantine(
        pharmacyId: pharmacyId,
        entryIds: straddle.map((e) => e.id).toList(),
        code: '23503',
        message: 'x',
      );

      final result = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );

      expect(result.isSuccess, isTrue);
      expect(result.pushed, 100);
      expect(pushedIds().toSet(), expectedPushed);
      expect(pushedIds().where(straddle.map((e) => e.id).contains), isEmpty);
      expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), hasLength(150));
    },
  );

  test(
    'permanent SQLSTATE quarantines the batch with exactly one error-log '
    'record; rows stay unsynced and the pass is not a failure',
    () async {
      await appendEntry();
      await appendEntry();
      client.failAllPushes = true;
      client.pushError = const PostgrestException(
        message: 'Key (product_id)=(1) is not present in table "products"',
        code: '23503',
      );

      final result = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );

      expect(result.isSuccess, isTrue);
      expect(result.pushed, 0);
      expect(
        await quarantine.quarantinedEntryIds(pharmacyId: pharmacyId),
        hasLength(2),
      );
      expect(
        await ledger.unsyncedEntries(pharmacyId: pharmacyId),
        hasLength(2),
      );
      final records = await errorLog.unreportedEntries();
      expect(records, hasLength(1));
      expect(records.single.message, contains('23503'));
      expect(records.single.message, contains('2 entries'));
    },
  );

  test(
    'quarantined entries are excluded from push candidates on later passes',
    () async {
      await appendMany(3);
      client.failNextPush = true;
      client.pushError = const PostgrestException(message: 'x', code: '23503');

      final first = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );
      expect(first.isSuccess, isTrue);

      final second = await job.runOnce(
        pharmacyId: pharmacyId,
        credentials: credentials,
      );
      expect(second.isSuccess, isTrue);
      expect(second.pushed, 0);
      expect(client.pushedBatches, isEmpty);
      expect(
        await ledger.unsyncedEntries(pharmacyId: pharmacyId),
        hasLength(3),
      );
    },
  );

  test('23505 counts as success: rows stamped, never quarantined', () async {
    await appendEntry();
    client.failNextPush = true;
    client.pushError = const PostgrestException(message: 'duplicate', code: '23505');

    final result = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );

    expect(result.isSuccess, isTrue);
    expect(result.pushed, 1);
    expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), isEmpty);
    expect(
      await quarantine.quarantinedEntryIds(pharmacyId: pharmacyId),
      isEmpty,
    );
    expect(await errorLog.unreportedEntries(), isEmpty);
  });

  test(
    'auth SQLSTATE (401) stays transient: failure + backoff, no '
    'quarantine',
    () async {
    await appendEntry();
    client.failAllPushes = true;
    client.pushError = const PostgrestException(message: 'unauthorized', code: '401');

    final result = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );

    expect(result.isSuccess, isFalse);
    expect(result.suggestedRetryDelay, const Duration(seconds: 5));
    expect(
      await quarantine.quarantinedEntryIds(pharmacyId: pharmacyId),
      isEmpty,
    );
  });
}
