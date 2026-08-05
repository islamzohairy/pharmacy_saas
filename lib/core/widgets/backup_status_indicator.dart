import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/sync/backup_staleness.dart';
import '../data/sync/sync_providers.dart';
import '../data/sync/sync_scheduler.dart';
import '../l10n/app_l10n.dart';

/// The in-app "last backed up" indicator (plan 03 step 6) — the owner's
/// visibility into backup status, addressing the trust concern behind the
/// data-loss risk. Purely presentational: state comes from
/// [backupStatusProvider].
///
/// Plan 11 adds a third staleness layer on top of the existing sync states:
/// when unsynced entries sit past [backupStaleThreshold], the row turns
/// into a warning ("آخر نسخة احتياطية قديمة…") and tapping opens a
/// non-destructive explanation dialog. Staleness is derived in the sync
/// layer — this widget only renders it.
class BackupStatusIndicator extends ConsumerWidget {
  const BackupStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backupStatusProvider).status;
    final l10n = context.l10n;

    if (status.staleness == BackupStaleness.stale) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showStaleDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.backupStale,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (icon, label) = switch (status.state) {
      BackupSyncState.neverSynced => (Icons.cloud_off, l10n.backupNeverSynced),
      BackupSyncState.syncing => (Icons.cloud_sync, l10n.backupSyncing),
      BackupSyncState.synced => (
        Icons.cloud_done,
        l10n.backupSyncedAt(
          DateFormat('d/M/yyyy HH:mm').format(status.lastSyncedAt!),
        ),
      ),
      BackupSyncState.error => (Icons.error_outline, l10n.backupError),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /// Explains what stale means and what to do. Deliberately non-
  /// destructive — no reset, no delete (PLANS/11 §4.2).
  Future<void> _showStaleDialog(BuildContext context) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.backupStaleDialogTitle),
        content: Text(l10n.backupStaleDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.backupStaleDialogGotIt),
          ),
        ],
      ),
    );
  }
}
