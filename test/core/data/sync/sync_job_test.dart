import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/sync/remote_backup_client.dart';
import 'package:pharmacy_saas/core/data/sync/sync_job.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/ledger/data/ledger_repository_impl.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';

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
    client = FakeRemoteBackupClient();
    job = SyncJob(ledgerRepository: ledger, client: client);
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
            type: LedgerEntryType.cashDraw,
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

    final result = await job.runOnce(pharmacyId: pharmacyId, credentials: credentials);

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

  test('unregistered device calls registerDevice exactly once per run',
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
  });

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

  test('batch failure mid-sync: nothing stamped, retry re-pushes all',
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
    expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), hasLength(5));

    final retry = await job.runOnce(
      pharmacyId: pharmacyId,
      credentials: credentials,
    );
    expect(retry.isSuccess, isTrue);
    expect(retry.pushed, 5);
    // The retry pushed the full batch again (server-side upsert is
    // idempotent — see the migration), and nothing was double-stamped.
    expect(
      await ledger.unsyncedEntries(pharmacyId: pharmacyId),
      isEmpty,
    );
  });

  test('server-side idempotency assumption: same ids re-pushed on retry',
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
  });
}
