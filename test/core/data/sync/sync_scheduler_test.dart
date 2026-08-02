import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/sync/remote_backup_client.dart';
import 'package:pharmacy_saas/core/data/sync/sync_scheduler.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/identity/domain/identity_repository.dart';
import 'package:pharmacy_saas/features/identity/domain/pharmacy.dart';
import 'package:pharmacy_saas/features/identity/domain/user_profile.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_repository.dart';

/// Drift-free fakes so the scheduler's timing logic is testable with
/// fake_async (no isolate messages).
class FakeLedger implements LedgerRepository {
  final List<LedgerEntry> _pending = [];
  final _unsyncedController = StreamController<int>.broadcast();

  /// Synchronously inspectable — avoids `completion(...)` matchers, whose
  /// continuations freeze once the fakeAsync zone exits.
  int get pendingCount => _pending.length;

  void addPending(LedgerEntry entry) {
    _pending.add(entry);
    _unsyncedController.add(_pending.length);
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
  }) =>
      const Stream.empty();

  @override
  Stream<List<LedgerEntry>> watchEntriesByParty({
    required int pharmacyId,
    required LedgerEntryType type,
    required int partyId,
  }) =>
      const Stream.empty();

  @override
  Future<List<LedgerEntry>> unsyncedEntries({
    required int pharmacyId,
    int limit = 200,
  }) async =>
      _pending.take(limit).toList();

  @override
  Stream<int> watchUnsyncedCount({required int pharmacyId}) =>
      _unsyncedController.stream;

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

void main() {
  test('unconfigured backend: start() is a quiet no-op', () {
    fakeAsync((async) {
      final status = BackupStatusNotifier();
      final scheduler = SyncScheduler(
        ledgerRepository: FakeLedger(),
        identityRepository: FakeIdentity()..pharmacy = _pharmacy(),
        client: FakeRemoteBackupClient(configured: false),
        status: status,
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
      );
      scheduler.start();
      async.elapse(const Duration(minutes: 2));
      scheduler.dispose();
      expect(status.status.state, BackupSyncState.neverSynced);
    });
  });

  test('start() syncs pending entries immediately and reports synced',
      () {
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
}

Pharmacy _pharmacy() => Pharmacy(
  id: 1,
  name: 'صيدلية النور',
  currency: 'EGP',
  createdAt: DateTime(2026, 8, 2),
  remoteUuid: 'uuid',
);

LedgerEntry _entry(int id) => LedgerEntry(
  id: id,
  pharmacyId: 1,
  type: LedgerEntryType.cashDraw,
  amountMinor: 100,
  occurredAt: DateTime(2026, 8, 2, 10),
);
