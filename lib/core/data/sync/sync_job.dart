import '../../../../features/ledger/domain/ledger_entry.dart';
import '../../../../features/ledger/domain/ledger_repository.dart';
import 'remote_backup_client.dart';

/// Everything the sync job needs to identify the device and its tenant.
/// Assembled by the scheduler from the identity layer — the job itself
/// only consumes plain values.
class SyncCredentials {
  const SyncCredentials({
    required this.deviceToken,
    required this.deviceRegistered,
    required this.pharmacyUuid,
    required this.pharmacyName,
    required this.currency,
  });

  final String deviceToken;
  final bool deviceRegistered;
  final String pharmacyUuid;
  final String pharmacyName;
  final String currency;
}

/// Outcome of one sync pass.
class SyncResult {
  const SyncResult.success({required this.pushed})
    : error = null,
      suggestedRetryDelay = Duration.zero;

  const SyncResult.failure(this.error, this.suggestedRetryDelay, {this.pushed = 0});

  /// Returned when no backend is configured — not an error, just nothing
  /// to do.
  const SyncResult.skipped()
    : pushed = 0,
      error = null,
      suggestedRetryDelay = Duration.zero;

  final int pushed;
  final Object? error;

  /// How long the scheduler should wait before trying again after a
  /// failure (exponential backoff, capped).
  final Duration suggestedRetryDelay;

  bool get isSuccess => error == null;
  bool get isSkipped => pushed == 0 && error == null;
}

/// One-way backup of unsynced ledger rows to the remote target.
///
/// Local-first: the job reads unsynced rows, pushes them in batches via
/// [RemoteBackupClient], and stamps `synced_at` **only after** the push
/// succeeds. Combined with the server's idempotent upsert keyed on
/// `(pharmacy_id, id)`, an app killed mid-sync neither loses nor
/// duplicates entries — the next pass re-pushes and the server ignores
/// what's already there.
///
/// Never throws: failures are returned as [SyncResult.failure] with a
/// suggested retry delay so the scheduler can back off. UI is never
/// blocked — the caller decides how to schedule this.
class SyncJob {
  SyncJob({required this.ledgerRepository, required this.client});

  final LedgerRepository ledgerRepository;
  final RemoteBackupClient client;

  static const _batchSize = 200;
  static const _initialRetryDelay = Duration(seconds: 5);
  static const _maxRetryDelay = Duration(minutes: 5);

  int _consecutiveFailures = 0;

  /// Runs one sync pass. [onRegistered] is invoked once when this pass
  /// performed the first-time device registration.
  Future<SyncResult> runOnce({
    required int pharmacyId,
    required SyncCredentials credentials,
    Future<void> Function()? onRegistered,
  }) async {
    if (!client.isConfigured) return const SyncResult.skipped();

    try {
      if (!credentials.deviceRegistered) {
        await client.registerDevice(
          deviceToken: credentials.deviceToken,
          pharmacyUuid: credentials.pharmacyUuid,
          pharmacyName: credentials.pharmacyName,
          currency: credentials.currency,
        );
        await onRegistered?.call();
      }

      var pushed = 0;
      while (true) {
        final batch = await ledgerRepository.unsyncedEntries(
          pharmacyId: pharmacyId,
          limit: _batchSize,
        );
        if (batch.isEmpty) break;
        await client.pushLedgerEntries(
          deviceToken: credentials.deviceToken,
          entries: batch.map(_toRemote).toList(),
        );
        await ledgerRepository.markSynced(
          pharmacyId: pharmacyId,
          ids: batch.map((e) => e.id).toList(),
          at: DateTime.now().toUtc(),
        );
        pushed += batch.length;
      }

      _consecutiveFailures = 0;
      return SyncResult.success(pushed: pushed);
    } catch (error) {
      _consecutiveFailures++;
      final delay = _nextRetryDelay();
      return SyncResult.failure(error, delay);
    }
  }

  Duration _nextRetryDelay() {
    var delay = _initialRetryDelay;
    for (var i = 1; i < _consecutiveFailures; i++) {
      delay *= 2;
      if (delay >= _maxRetryDelay) return _maxRetryDelay;
    }
    return delay;
  }

  RemoteLedgerEntry _toRemote(LedgerEntry entry) => RemoteLedgerEntry(
    id: entry.id,
    type: entry.type.wireName,
    amountMinor: entry.amountMinor,
    occurredAt: entry.occurredAt,
    productId: entry.productId,
    supplierId: entry.supplierId,
    customerId: entry.customerId,
    profileId: entry.profileId,
    note: entry.note,
  );
}
