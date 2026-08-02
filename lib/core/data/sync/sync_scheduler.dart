import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../features/identity/domain/identity_repository.dart';
import '../../../features/identity/domain/pharmacy.dart';
import '../../../features/ledger/domain/ledger_repository.dart';
import 'remote_backup_client.dart';
import 'sync_job.dart';

/// What the in-app "last backed up" indicator renders.
enum BackupSyncState { neverSynced, syncing, synced, error }

class BackupStatus {
  const BackupStatus({
    required this.state,
    this.lastSyncedAt,
    this.backlogCount = 0,
    this.lastError,
  });

  const BackupStatus.initial()
    : state = BackupSyncState.neverSynced,
      lastSyncedAt = null,
      backlogCount = 0,
      lastError = null;

  final BackupSyncState state;
  final DateTime? lastSyncedAt;
  final int backlogCount;
  final String? lastError;
}

/// Listens to backup status; consumed by the indicator widget via
/// Riverpod's ChangeNotifierProvider.
class BackupStatusNotifier extends ChangeNotifier {
  BackupStatus _status = const BackupStatus.initial();

  BackupStatus get status => _status;

  void update(BackupStatus status) {
    _status = status;
    notifyListeners();
  }
}

/// Triggers and backoff for the one-way backup job.
///
/// Triggers (per plan 03): app start, app foreground resume, any ledger
/// write (observed via the unsynced-backlog stream, debounced), and a
/// periodic foreground timer. No WorkManager in P0 — the app's sync
/// surface is ledger writes plus foreground activity, and retry-with-
/// backoff covers connectivity gaps; WorkManager is deferred (see
/// DECISIONS.md).
///
/// This is cross-feature infrastructure living in `core`, which is why it
/// depends on the `identity` and `ledger` feature barrels through their
/// interfaces — the one deliberate core→feature import in the codebase.
class SyncScheduler {
  SyncScheduler({
    required this.ledgerRepository,
    required this.identityRepository,
    required this.client,
    required this.status,
  }) : _job = SyncJob(ledgerRepository: ledgerRepository, client: client);

  final LedgerRepository ledgerRepository;
  final IdentityRepository identityRepository;
  final RemoteBackupClient client;
  final BackupStatusNotifier status;

  static const _periodicInterval = Duration(seconds: 60);
  static const _writeDebounce = Duration(seconds: 5);

  final SyncJob _job;

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  StreamSubscription<int>? _backlogSubscription;
  bool _running = false;

  /// Subscribes to the ledger backlog and schedules the periodic pass.
  /// Idempotent; safe to call once at app start.
  void start() {
    if (_periodicTimer != null) return;
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => _run());
    _run();
  }

  /// Called from the app-lifecycle observer on foreground resume.
  Future<void> onAppResumed() async {
    _debounceTimer?.cancel();
    await _run();
  }

  void dispose() {
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _backlogSubscription?.cancel();
  }

  Future<void> _run() async {
    if (_running || !client.isConfigured) return;
    _running = true;
    try {
      final Pharmacy pharmacy;
      try {
        pharmacy = await identityRepository.getPharmacy();
      } on StateError {
        return; // onboarding not complete — nothing to back up yet.
      }
      _ensureBacklogSubscription(pharmacy.id);

      final registered = await identityRepository.isDeviceRegistered();
      final credentials = SyncCredentials(
        deviceToken: await identityRepository.getDeviceToken(),
        deviceRegistered: registered,
        pharmacyUuid: pharmacy.remoteUuid ?? '',
        pharmacyName: pharmacy.name,
        currency: pharmacy.currency,
      );
      if (credentials.pharmacyUuid.isEmpty) {
        return; // pre-plan-03 installs lack the binding key; skip safely.
      }

      status.update(
        BackupStatus(
          state: BackupSyncState.syncing,
          lastSyncedAt: status.status.lastSyncedAt,
          backlogCount: status.status.backlogCount,
        ),
      );

      final result = await _job.runOnce(
        pharmacyId: pharmacy.id,
        credentials: credentials,
        onRegistered: identityRepository.markDeviceRegistered,
      );

      if (result.isSkipped) return;

      if (result.isSuccess) {
        if (result.pushed > 0 || !registered) {
          status.update(
            BackupStatus(
              state: BackupSyncState.synced,
              lastSyncedAt: DateTime.now(),
              backlogCount: 0,
            ),
          );
        }
        _retryTimer?.cancel();
      } else {
        status.update(
          BackupStatus(
            state: BackupSyncState.error,
            lastSyncedAt: status.status.lastSyncedAt,
            backlogCount: status.status.backlogCount,
            lastError: '${result.error}',
          ),
        );
        _retryTimer?.cancel();
        _retryTimer = Timer(result.suggestedRetryDelay, _run);
      }
    } finally {
      _running = false;
    }
  }

  void _ensureBacklogSubscription(int pharmacyId) {
    if (_backlogSubscription != null) return;
    _backlogSubscription = ledgerRepository
        .watchUnsyncedCount(pharmacyId: pharmacyId)
        .listen((count) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(_writeDebounce, () {
            status.update(
              BackupStatus(
                state: status.status.state,
                lastSyncedAt: status.status.lastSyncedAt,
                backlogCount: count,
              ),
            );
            _run();
          });
        });
  }
}
