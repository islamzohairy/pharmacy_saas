import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/error_log_providers.dart';
import 'package:pharmacy_saas/core/data/error_log_repository.dart';
import 'package:pharmacy_saas/core/data/sync/backup_staleness.dart';
import 'package:pharmacy_saas/core/data/sync/quarantine_repository.dart';
import 'package:pharmacy_saas/core/data/sync/remote_backup_client.dart';
import 'package:pharmacy_saas/core/data/sync/sync_providers.dart';
import 'package:pharmacy_saas/core/data/sync/sync_scheduler.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/identity/domain/identity_repository.dart';
import 'package:pharmacy_saas/features/identity/domain/pharmacy.dart';
import 'package:pharmacy_saas/features/identity/domain/user_profile.dart';
import 'package:pharmacy_saas/features/identity/presentation/identity_providers.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_repository.dart';
import 'package:pharmacy_saas/features/ledger/presentation/ledger_providers.dart';

/// Drift-free fakes so the scheduler's timing logic is testable with
/// fake_async (no isolate messages).
class FakeLedger implements LedgerRepository {
  final List<LedgerEntry> _pending = [];
  final _unsyncedController = StreamController<int>.broadcast();

  /// Newest stamp written by [markSynced], for the derived
  /// [lastSyncedAt] read — `null` until anything was pushed.
  DateTime? lastSynced;

  /// Synchronously inspectable — avoids `completion(...)` matchers, whose
  /// continuations freeze once the fakeAsync zone exits.
  int get pendingCount => _pending.length;

  void addPending(LedgerEntry entry) {
    _pending.add(entry);
    _unsyncedController.add(_pending.length);
  }

  void stampAll(DateTime at) {
    lastSynced = at;
    _pending.clear();
    _unsyncedController.add(0);
  }

  @override
  Future<LedgerEntry> append(LedgerEntryDraft draft) async {
    final entry = LedgerEntry(
      id: _pending.length + 1,
      pharmacyId: draft.pharmacyId,
      type: draft.type,
      amountMinor: draft.amountMinor,
      occurredAt: draft.occurredAt,
    );
    addPending(entry);
    return entry;
  }

  @override
  Stream<List<LedgerEntry>> watchEntries({
    required int pharmacyId,
    DateTime? from,
    DateTime? to,
    LedgerEntryType? type,
    int? limit,
  }) => const Stream.empty();

  @override
  Stream<List<LedgerEntry>> watchEntriesByParty({
    required int pharmacyId,
    required LedgerEntryType type,
    required int partyId,
  }) => const Stream.empty();

  @override
  Future<List<LedgerEntry>> unsyncedEntries({
    required int pharmacyId,
    int limit = 200,
    List<int> excludeIds = const [],
  }) async =>
      _pending.where((e) => !excludeIds.contains(e.id)).take(limit).toList();

  @override
  Stream<int> watchUnsyncedCount({required int pharmacyId}) =>
      _unsyncedController.stream;

  @override
  Future<DateTime?> oldestUnsyncedAt({required int pharmacyId}) async {
    if (_pending.isEmpty) return null;
    return _pending.map((e) => e.occurredAt).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  @override
  Future<DateTime?> lastSyncedAt({required int pharmacyId}) async =>
      lastSynced;

  @override
  Future<void> markSynced({
    required int pharmacyId,
    required List<int> ids,
    required DateTime at,
  }) async {
    _pending.removeWhere((e) => ids.contains(e.id));
    _unsyncedController.add(_pending.length);
  }
}

class FakeIdentity implements IdentityRepository {
  Pharmacy? pharmacy;
  bool registered = false;
  String token = 'device-token';

  @override
  Future<bool> hasAnyProfile() async => pharmacy != null;

  @override
  Future<({Pharmacy pharmacy, UserProfile owner})> createPharmacyAndOwner({
    required String pharmacyName,
    required String currency,
    required String ownerDisplayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Pharmacy> getPharmacy() async {
    final p = pharmacy;
    if (p == null) throw StateError('No pharmacy on this device yet');
    return p;
  }

  @override
  Future<Pharmacy> updatePharmacySettings({
    required String? taxRegistrationNumber,
    required String? legalBusinessName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> getDeviceToken() async => token;

  @override
  Future<bool> isDeviceRegistered() async => registered;

  @override
  Future<void> markDeviceRegistered() async {
    registered = true;
  }

  @override
  Future<List<UserProfile>> getProfiles() async => [];

  @override
  Future<UserProfile> addFamilyProfile({required String displayName}) {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile?> getProfile(int id) async => null;

  @override
  Future<void> setPin(UserProfile profile, String pin) {
    throw UnimplementedError();
  }

  @override
  Future<bool> verifyPin(UserProfile profile, String pin) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearPin(UserProfile profile) {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile?> getLastActiveProfile() async => null;

  @override
  Future<void> setLastActiveProfile(UserProfile profile) {
    throw UnimplementedError();
  }

  @override
  Future<void> wipeLocalIdentity() {
    throw UnimplementedError();
  }
}

class FakeRemoteBackupClient implements RemoteBackupClient {
  FakeRemoteBackupClient({this.configured = true});

  bool configured;
  bool failPush = false;
  int pushCalls = 0;
  int registerCalls = 0;
  bool gotOnRegistered = false;

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
    if (failPush) throw Exception('push failed');
    return entries.length;
  }
}

/// Quarantine/error-log no-ops for the scheduler timing tests — none of
/// them provoke permanent failures, so the fakes record nothing.
class FakeQuarantine implements QuarantineRepository {
  FakeQuarantine({this.excluded = const {}});

  /// Which entry ids the sync job must treat as quarantined.
  final Set<int> excluded;

  @override
  Future<void> quarantine({
    required int pharmacyId,
    required List<int> entryIds,
    required String code,
    String? message,
  }) async {}

  @override
  Future<Set<int>> quarantinedEntryIds({required int pharmacyId}) async =>
      excluded;
}

class FakeErrorLog implements ErrorLogRepository {
  final List<String> records = [];

  @override
  Future<void> record({
    required String errorType,
    required String message,
    String? stackTrace,
  }) async {
    records.add('$errorType: $message');
  }

  @override
  Future<void> markAllReported() async {}

  @override
  Future<List<StoredErrorLogEntry>> unreportedEntries() async => [];

  @override
  Stream<int> watchUnreportedCount() => const Stream.empty();
}

void main() {
  test('unconfigured backend: start() is a quiet no-op', () {
    fakeAsync((async) {
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: FakeLedger(),
        identityRepository: FakeIdentity()..pharmacy = _pharmacy(),
        client: FakeRemoteBackupClient(configured: false),
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );
      scheduler.start();
      async.elapse(const Duration(minutes: 2));
      scheduler.dispose();
      expect(status.status.state, BackupSyncState.neverSynced);
    });
  });

  test('no pharmacy yet (pre-onboarding): start() is a quiet no-op', () {
    fakeAsync((async) {
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: FakeLedger(),
        identityRepository: FakeIdentity(),
        client: FakeRemoteBackupClient(),
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );
      scheduler.start();
      async.elapse(const Duration(minutes: 2));
      scheduler.dispose();
      expect(status.status.state, BackupSyncState.neverSynced);
    });
  });

  test('start() syncs pending entries immediately and reports synced', () {
    fakeAsync((async) {
      final ledger = FakeLedger();
      ledger.addPending(_entry(1));
      final identity = FakeIdentity()..pharmacy = _pharmacy();
      final client = FakeRemoteBackupClient();
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: ledger,
        identityRepository: identity,
        client: client,
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );

      scheduler.start();
      async.flushMicrotasks();

      expect(client.pushCalls, 1);
      expect(identity.registered, isTrue);
      expect(ledger.pendingCount, 0);
      expect(status.status.state, BackupSyncState.synced);
      expect(status.status.lastSyncedAt, isNotNull);
      scheduler.dispose();
    });
  });

  test('no-op pass (registered, nothing pending) shows the derived last '
      'sync time instead of lingering at syncing', () {
    fakeAsync((async) {
      final ledger = FakeLedger();
      ledger.stampAll(DateTime(2026, 8, 5, 11, 10));
      final identity = FakeIdentity()..pharmacy = _pharmacy()..registered = true;
      final client = FakeRemoteBackupClient();
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: ledger,
        identityRepository: identity,
        client: client,
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );

      scheduler.start();
      async.flushMicrotasks();

      expect(client.registerCalls, 0);
      expect(client.pushCalls, 0);
      expect(status.status.state, BackupSyncState.synced);
      expect(status.status.lastSyncedAt, DateTime(2026, 8, 5, 11, 10));
      scheduler.dispose();
    });
  });

  test('no-op pass with nothing ever stamped keeps the prior state', () {
    fakeAsync((async) {
      final ledger = FakeLedger();
      final identity = FakeIdentity()..pharmacy = _pharmacy()..registered = true;
      final client = FakeRemoteBackupClient();
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: ledger,
        identityRepository: identity,
        client: client,
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );

      scheduler.start();
      async.flushMicrotasks();

      expect(status.status.state, BackupSyncState.neverSynced);
      scheduler.dispose();
    });
  });

  test('a ledger write triggers a debounced sync pass', () {
    fakeAsync((async) {
      final ledger = FakeLedger();
      final identity = FakeIdentity()..pharmacy = _pharmacy();
      final client = FakeRemoteBackupClient();
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: ledger,
        identityRepository: identity,
        client: client,
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );

      scheduler.start();
      async.flushMicrotasks();
      // Nothing pending yet: the start pass registers the device only.
      expect(client.registerCalls, 1);
      expect(client.pushCalls, 0);

      // A new write appears on the backlog stream.
      ledger.addPending(_entry(2));
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();

      expect(client.pushCalls, 1);
      expect(ledger.pendingCount, 0);
      expect(status.status.state, BackupSyncState.synced);
      scheduler.dispose();
    });
  });

  test('failure flips status to error and retries after backoff', () {
    fakeAsync((async) {
      final ledger = FakeLedger();
      ledger.addPending(_entry(1));
      final identity = FakeIdentity()..pharmacy = _pharmacy();
      final client = FakeRemoteBackupClient()..failPush = true;
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: ledger,
        identityRepository: identity,
        client: client,
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );

      scheduler.start();
      async.flushMicrotasks();
      expect(status.status.state, BackupSyncState.error);
      expect(client.pushCalls, 1);

      // Backend recovers; the 5s backoff retry succeeds.
      client.failPush = false;
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(client.pushCalls, 2);
      expect(status.status.state, BackupSyncState.synced);
      scheduler.dispose();
    });
  });

  test('unsynced entries older than the threshold turn the status stale',
      () {
    fakeAsync((async) {
      final ledger = FakeLedger();
      final identity = FakeIdentity()..pharmacy = _pharmacy();
      // Push fails, so the old backlog can't be cleared — the steady
      // state of a device whose backup has been failing for 2+ days.
      final client = FakeRemoteBackupClient()..failPush = true;
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: ledger,
        identityRepository: identity,
        client: client,
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );

      scheduler.start();
      async.flushMicrotasks();
      expect(status.status.staleness, BackupStaleness.healthy);

      // A very old unsynced entry appears (e.g. a pre-existing backlog
      // after days offline) — the write-debounce re-derives staleness.
      ledger.addPending(
        _entry(2, occurredAt: DateTime.now().subtract(const Duration(hours: 49))),
      );
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();

      expect(status.status.staleness, BackupStaleness.stale);
      expect(status.status.backlogCount, 1);
      scheduler.dispose();
    });
  });

  test('a successful sync pass clears staleness back to healthy', () {
    fakeAsync((async) {
      final ledger = FakeLedger();
      final identity = FakeIdentity()..pharmacy = _pharmacy();
      final client = FakeRemoteBackupClient()..failPush = true;
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: ledger,
        identityRepository: identity,
        client: client,
        status: status,
        quarantineRepository: FakeQuarantine(),
        errorLogRepository: FakeErrorLog(),
      );

      scheduler.start();
      async.flushMicrotasks();

      ledger.addPending(
        _entry(2, occurredAt: DateTime.now().subtract(const Duration(hours: 49))),
      );
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(status.status.staleness, BackupStaleness.stale);

      // The backlog empties (a later sync pass succeeded) — the count
      // stream emits 0, the debounce fires, and staleness drops back to
      // healthy.
      ledger.markSynced(pharmacyId: 1, ids: const [2], at: DateTime.now());
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(status.status.staleness, BackupStaleness.healthy);
      expect(status.status.backlogCount, 0);
      scheduler.dispose();
    });
  });

  test(
    'all entries quarantined: chip shows a sane never-synced state and '
    'staleness still climbs (staff-review condition 3)',
    () {
      fakeAsync((async) {
        final ledger = FakeLedger();
        final identity = FakeIdentity()..pharmacy = _pharmacy()..registered = true;
        final client = FakeRemoteBackupClient();
        final status = BackupStatusNotifier();
        final quarantine = FakeQuarantine(excluded: {1, 2});
        final scheduler = SyncScheduler(
          ledgerRepository: ledger,
          identityRepository: identity,
          client: client,
          status: status,
          quarantineRepository: quarantine,
          errorLogRepository: FakeErrorLog(),
        );

        scheduler.start();
        async.flushMicrotasks();

        // The quarantine empties the push candidates; nothing was ever
        // stamped, so the chip never claims a sync.
        ledger.addPending(_entry(1, occurredAt: _oldDate()));
        ledger.addPending(_entry(2, occurredAt: _oldDate()));
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(client.pushCalls, 0);
        expect(status.status.state, BackupSyncState.neverSynced);
        expect(status.status.backlogCount, 2);
        expect(status.status.staleness, BackupStaleness.stale);

        scheduler.dispose();
      });
    },
  );

  test(
    'quarantined entries are excluded from push candidates but counted in '
    'the backlog (staff-review condition 3)',
    () {
      fakeAsync((async) {
        final ledger = FakeLedger();
        final identity = FakeIdentity()..pharmacy = _pharmacy()..registered = true;
        final client = FakeRemoteBackupClient();
        final status = BackupStatusNotifier();
        final quarantine = FakeQuarantine(excluded: {2, 3});
        final scheduler = SyncScheduler(
          ledgerRepository: ledger,
          identityRepository: identity,
          client: client,
          status: status,
          quarantineRepository: quarantine,
          errorLogRepository: FakeErrorLog(),
        );

        scheduler.start();
        async.flushMicrotasks();

        // A new write appears: two entries quarantined, one pushable.
        ledger.addPending(_entry(1, occurredAt: _oldDate()));
        ledger.addPending(_entry(2, occurredAt: _oldDate()));
        ledger.addPending(_entry(3, occurredAt: _oldDate()));
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Exactly one push — the quarantined entries were never re-sent.
        expect(client.pushCalls, 1);
        expect(ledger.pendingCount, 2);
        expect(status.status.state, BackupSyncState.synced);

        // The quarantined backlog is still visible and still stale.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(status.status.backlogCount, 2);
        expect(status.status.staleness, BackupStaleness.stale);

        scheduler.dispose();
      });
    },
  );

  test(
    'status writes do not dispose the scheduler provider (regression: '
    'provider self-watch)',
    () {
      fakeAsync((async) {
        final ledger = FakeLedger();
        final identity = FakeIdentity()..pharmacy = _pharmacy();
        final client = FakeRemoteBackupClient();
        final container = ProviderContainer(
          overrides: [
            ledgerRepositoryProvider.overrideWithValue(ledger),
            identityRepositoryProvider.overrideWithValue(identity),
            remoteBackupClientProvider.overrideWithValue(client),
            quarantineRepositoryProvider.overrideWithValue(FakeQuarantine()),
            errorLogRepositoryProvider.overrideWithValue(FakeErrorLog()),
          ],
        );
        addTearDown(container.dispose);

        final scheduler = container.read(syncSchedulerProvider);
        scheduler.start();
        async.flushMicrotasks();

        // The first pass just completed (nothing pending — registration
        // only) — and its own status.update is the poison pill: under the
        // old wiring (ref.watch(backupStatusProvider) inside
        // syncSchedulerProvider) every notifyListeners invalidated this
        // provider mid-pass, running ref.onDispose → scheduler.dispose,
        // which canceled the timers and the backlog subscription. The
        // provider must still serve the SAME live instance.
        expect(client.pushCalls, 0);
        expect(
          identical(container.read(syncSchedulerProvider), scheduler),
          isTrue,
          reason: 'the scheduler must not be rebuilt by its own status writes',
        );

        // And the machinery must still be live end-to-end: a new write
        // still flows through the subscription to the debounce and out to
        // a push.
        ledger.addPending(_entry(2));
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(client.pushCalls, 1);
        expect(ledger.pendingCount, 0);
        scheduler.dispose();
      });
    },
  );
}

Pharmacy _pharmacy({int id = 1}) => Pharmacy(
  id: id,
  name: 'صيدلية النور',
  currency: 'EGP',
  createdAt: DateTime(2026, 8, 2),
  remoteUuid: 'uuid',
);

LedgerEntry _entry(int id, {DateTime? occurredAt}) => LedgerEntry(
  id: id,
  pharmacyId: 1,
  type: LedgerEntryType.expense,
  amountMinor: 100,
  occurredAt: occurredAt ?? DateTime(2026, 8, 2, 10),
);

/// Far past the staleness threshold (49h, matching the existing stale
/// tests) so any backlog drives the chip stale.
DateTime _oldDate() => DateTime.now().subtract(const Duration(hours: 49));
