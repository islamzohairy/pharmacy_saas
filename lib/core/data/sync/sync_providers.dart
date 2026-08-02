import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/identity/presentation/identity_providers.dart';
import '../../../features/ledger/presentation/ledger_providers.dart';
import 'remote_backup_client.dart';
import 'supabase_backup_client.dart';
import 'sync_scheduler.dart';

/// The remote backup surface. Override in tests with a fake client.
final remoteBackupClientProvider = Provider<RemoteBackupClient>(
  (ref) => SupabaseRemoteBackupClient(),
);

/// Backup status for the in-app "last backed up" indicator.
final backupStatusProvider = ChangeNotifierProvider<BackupStatusNotifier>(
  (ref) => BackupStatusNotifier(),
);

/// The sync scheduler. Instantiated lazily; `start()` is called once from
/// `main()` after the provider container is created.
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(
    ledgerRepository: ref.watch(ledgerRepositoryProvider),
    identityRepository: ref.watch(identityRepositoryProvider),
    client: ref.watch(remoteBackupClientProvider),
    status: ref.watch(backupStatusProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
