/// Backup-staleness derivation (PLANS/11 §4.2) — pure Dart, no drift, no
/// providers: the indicator renders the result, it never computes it.
///
/// Staleness is DERIVED from the existing sync state (the per-row
/// `synced_at IS NULL` flag), never stored: unsynced count + the oldest
/// unsynced entry's `occurred_at` are enough — zero schema change
/// (DECISIONS.md 2026-08-05).
library;

/// How long an unsynced entry may sit before the backup indicator turns
/// stale.
///
/// Rationale: the pilot app is used daily, so two missed days without a
/// successful backup is already a support conversation; the sync backoff
/// caps at 5 minutes, so a healthy-but-offline device never sits near this
/// bound (DECISIONS.md 2026-08-05).
const Duration backupStaleThreshold = Duration(hours: 48);

enum BackupStaleness { healthy, pending, stale }

/// Evaluates the staleness state from sync-state facts alone.
///
/// - `unsyncedCount == 0` → [BackupStaleness.healthy]. Covers the empty
///   ledger: a fresh install has nothing to lose and must never alarm.
/// - unsynced entries, all younger than [threshold] → [BackupStaleness.pending]
///   (current indicator behavior, unchanged).
/// - oldest unsynced entry older than [threshold] → [BackupStaleness.stale].
/// - `oldestUnsyncedAt == null` with a positive count is defensive
///   (count and oldest are read from the same predicate, so it can't
///   happen) → pending.
///
/// Clock manipulation: comparing against [now] means a clock set backward
/// yields a negative age → pending, masking staleness — accepted residual
/// risk for the pilot (DECISIONS.md 2026-08-05).
BackupStaleness evaluateBackupStaleness({
  required int unsyncedCount,
  required DateTime? oldestUnsyncedAt,
  required DateTime now,
  Duration threshold = backupStaleThreshold,
}) {
  if (unsyncedCount <= 0) return BackupStaleness.healthy;
  final oldest = oldestUnsyncedAt;
  if (oldest == null) return BackupStaleness.pending;
  return now.difference(oldest) > threshold
      ? BackupStaleness.stale
      : BackupStaleness.pending;
}
