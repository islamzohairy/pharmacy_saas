import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import 'remote_backup_client.dart';

/// Supabase-backed backup client.
///
/// All writes go through SECURITY DEFINER functions (`register_device`,
/// `push_ledger_entries`) — the anon role has no direct table access, and
/// the server resolves the tenant from the device token, never from
/// client-supplied ids (see the migration and DECISIONS.md).
///
/// Credentials come from `--dart-define` (`SUPABASE_URL`,
/// `SUPABASE_ANON_KEY`) and are never committed. With no credentials the
/// client reports [isConfigured] false and the sync job stays a no-op.
class SupabaseRemoteBackupClient implements RemoteBackupClient {
  @override
  bool get isConfigured => AppConfig.isSupabaseConfigured;

  @override
  Future<void> registerDevice({
    required String deviceToken,
    required String pharmacyUuid,
    required String pharmacyName,
    required String currency,
  }) async {
    await Supabase.instance.client.rpc<void>(
      'register_device',
      params: {
        'p_token': deviceToken,
        'p_pharmacy_uuid': pharmacyUuid,
        'p_pharmacy_name': pharmacyName,
        'p_currency': currency,
      },
    );
  }

  @override
  Future<int> pushLedgerEntries({
    required String deviceToken,
    required List<RemoteLedgerEntry> entries,
  }) async {
    final result = await Supabase.instance.client.rpc<int>(
      'push_ledger_entries',
      params: {
        'p_token': deviceToken,
        'p_entries': entries.map((e) => e.toJson()).toList(),
      },
    );
    return result;
  }
}
