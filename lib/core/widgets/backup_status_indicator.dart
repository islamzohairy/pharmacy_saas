import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/sync/sync_providers.dart';
import '../data/sync/sync_scheduler.dart';
import '../l10n/app_l10n.dart';

/// The in-app "last backed up" indicator (plan 03 step 6) — the owner's
/// visibility into backup status, addressing the trust concern behind the
/// data-loss risk. Purely presentational: state comes from
/// [backupStatusProvider].
class BackupStatusIndicator extends ConsumerWidget {
  const BackupStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backupStatusProvider).status;
    final l10n = context.l10n;

    final (icon, label) = switch (status.state) {
      BackupSyncState.neverSynced => (
        Icons.cloud_off,
        l10n.backupNeverSynced,
      ),
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
}
