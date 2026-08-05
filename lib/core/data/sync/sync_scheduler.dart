import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../features/identity/domain/identity_repository.dart';
import '../../../features/identity/domain/pharmacy.dart';
import '../../../features/ledger/domain/ledger_repository.dart';
import '../error_log_capture.dart';
import '../error_log_repository.dart';
import 'backup_staleness.dart';
import 'quarantine_repository.dart';
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
    this.staleness = BackupStaleness.healthy,
  });

  const BackupStatus.initial()
    : state = BackupSyncState.neverSynced,
      lastSyncedAt = null,
      backlogCount = 0,
      lastError = null,
      staleness = BackupStaleness.healthy;

  final BackupSyncState state;
  final DateTime? lastSyncedAt;
  final int backlogCount;
  final String? lastError;

  /// Derived, never stored (PLANS/11 §4.2): whether unsynced entries have
  /// sat past [backupStaleThreshold]. Evaluated on scheduler state changes
  /// only — no new timers or streams.
  final BackupStaleness staleness;
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
    required this.quarantineRepository,
    required this.errorLogRepository,
  }) : _job = SyncJob(
         ledgerRepository: ledgerRepository,
         client: client,
         quarantineRepository: quarantineRepository,
         errorLogRepository: errorLogRepository,
       );

  final LedgerRepository ledgerRepository;
  final IdentityRepository identityRepository;
  final RemoteBackupClient client;
  final BackupStatusNotifier status;
  final QuarantineRepository quarantineRepository;
  final ErrorLogRepository errorLogRepository;

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

      final previousStatus = status.status;
      status.update(
        BackupStatus(
          state: BackupSyncState.syncing,
          lastSyncedAt: status.status.lastSyncedAt,
          backlogCount: status.status.backlogCount,
          staleness: status.status.staleness,
        ),
      );

      final result = await _job.runOnce(
        pharmacyId: pharmacy.id,
        credentials: credentials,
        onRegistered: identityRepository.markDeviceRegistered,
      );

      if (result.isSkipped) {
        if (!registered) {
          // First pass: registration completed but there was nothing to
          // push yet — report synced (original semantics).
          status.update(
            BackupStatus(
              state: BackupSyncState.synced,
              lastSyncedAt: DateTime.now(),
              backlogCount: 0,
            ),
          );
        } else {
          // Genuine no-op pass (already registered, nothing to push):
          // derive the last successful push from stamped entries — a
          // relaunch must show the real last-sync time, not "never
          // synced" or a lingering "syncing" (observed live 2026-08-05
          // after the 0003 fix).
          final lastSyncedAt = await ledgerRepository.lastSyncedAt(
            pharmacyId: pharmacy.id,
          );
          if (lastSyncedAt != null) {
            status.update(
              BackupStatus(
                state: BackupSyncState.synced,
                lastSyncedAt: lastSyncedAt,
                backlogCount: 0,
              ),
            );
          } else {
            status.update(previousStatus);
          }
        }
        return;
      }

      if (result.isSuccess) {
        status.update(
          BackupStatus(
            state: BackupSyncState.synced,
            lastSyncedAt: DateTime.now(),
            backlogCount: 0,
          ),
        );
        _retryTimer?.cancel();
      } else {
        status.update(
          BackupStatus(
            state: BackupSyncState.error,
            lastSyncedAt: status.status.lastSyncedAt,
            backlogCount: status.status.backlogCount,
            lastError: '${result.error}',
            staleness: status.status.staleness,
          ),
        );
        _retryTimer?.cancel();
        _retryTimer = Timer(result.suggestedRetryDelay, _run);
      }

      // Every sync pass is a state change — re-derive staleness from the
      // current backlog (a successful pass with pushed>0 set count 0 above,
      // so this lands healthy; a failed pass keeps the entries, so this
      // reflects their age).
      await _refreshStaleness(pharmacy.id);
    } catch (error, stack) {
      // Phase 0 finding (PLANS/11 V3): identity-layer edge throws (token
      // reads etc.) must go through the shared error sink instead of
      // escaping to the lifecycle callback. Logging is fire-and-forget —
      // a logging bug can never take the scheduler down.
      reportZoneErrors(error, stack);
    } finally {
      _running = false;
    }
  }

  /// Re-derives [BackupStatus.staleness] with one bounded query (oldest
  /// unsynced `occurred_at`, tenant-prefix indexed). Called only on
  /// scheduler state changes — the write-debounce and sync-pass
  /// completion — never on a timer of its own (PLANS/11 §12).
  Future<void> _refreshStaleness(int pharmacyId) async {
    final current = status.status;
    final oldest = await ledgerRepository.oldestUnsyncedAt(
      pharmacyId: pharmacyId,
    );
    status.update(
      BackupStatus(
        state: current.state,
        lastSyncedAt: current.lastSyncedAt,
        backlogCount: current.backlogCount,
        lastError: current.lastError,
        staleness: evaluateBackupStaleness(
          unsyncedCount: current.backlogCount,
          oldestUnsyncedAt: oldest,
          now: DateTime.now(),
        ),
      ),
    );
  }

  void _ensureBacklogSubscription(int pharmacyId) {
    if (_backlogSubscription != null) return;
    _backlogSubscription = ledgerRepository
        .watchUnsyncedCount(pharmacyId: pharmacyId)
        .listen((count) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(_writeDebounce, () async {
            status.update(
              BackupStatus(
                state: status.status.state,
                lastSyncedAt: status.status.lastSyncedAt,
                backlogCount: count,
                lastError: status.status.lastError,
                staleness: status.status.staleness,
              ),
            );
            await _refreshStaleness(pharmacyId);
            unawaited(_run());
          });
        });
  }
}
