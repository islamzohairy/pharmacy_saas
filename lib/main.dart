import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/app_database.dart';
import 'core/data/database_providers.dart';
import 'core/data/error_log_capture.dart';
import 'core/data/sync/sync_providers.dart';
import 'core/router/app_router.dart';
import 'core/widgets/database_fatal_error_screen.dart';
import 'features/identity/data/identity_repository_impl.dart';

/// The app runs inside a guarded zone so that async/zone errors that
/// escape Flutter's framework handlers still reach the local error log
/// (PLANS/09 layer 1 — see [installErrorLogCapture]).
void main() {
  // Zone errors keep flowing to MCP's monitor (as bootstrapFlutter's default
  // onZoneError provided) before our log — see DECISIONS.md 2026-08-03 entry.
  runZonedGuarded(_startup, (error, stack) {
    MCPToolkitBinding.instance.handleZoneError(error, stack);
    reportZoneErrors(error, stack);
  });
}

Future<void> _startup() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Arabic date/number symbols for intl (NumberFormat/DateFormat with the
  // `ar` locale) — the localization delegates also load these, but this
  // covers any non-widget use.
  await initializeDateFormatting('ar');

  await SupabaseBootstrap.initializeIfConfigured();

  final AppDatabase database;
  try {
    database = await openAppDatabase();
  } catch (error, stack) {
    // The local DB cannot open (corrupt file, lost encryption key, failing
    // migration). The file is NEVER deleted/recreated by the open path
    // (PLANS/11 §4.3), so data is intact — the fatal screen only reassures,
    // exports a minimal report, and retries on the user's tap. Error
    // capture isn't installed (it needs the DB), so this screen IS the
    // fallback surface; the zone guard also still tries to log it.
    reportZoneErrors(error, stack);
    runApp(
      DatabaseFatalErrorApp(
        report: _databaseOpenReport(error, stack),
        retry: _retryOpen,
      ),
    );
    return;
  }

  await _runApp(database);
}

/// Retry path for the fatal-error screen: re-attempt the open, then launch
/// the real app on success. Throws on failure so the screen can surface it
/// (no silent loops).
Future<void> _retryOpen() async {
  await _runApp(await openAppDatabase());
}

/// Minimal plain-text artifact for support: timestamp, error type/message
/// (truncated), and the DB path. No ledger content — the DB is unreachable
/// at this point, so none can leak (PLANS/11 §11).
String _databaseOpenReport(Object error, StackTrace stack) {
  final message = error.toString();
  final truncated = message.length > 500 ? message.substring(0, 500) : message;
  final date = DateFormat('d/M/yyyy HH:mm').format(DateTime.now());
  return 'تقرير خطأ فتح البيانات\n'
      '----\n'
      '[$date] ${error.runtimeType}\n'
      '$truncated\n'
      'stack:\n'
      '${stack.toString().split('\n').take(8).join('\n')}';
}

/// The tail of startup — everything that needs a successfully opened
/// database. Reused by the fatal screen's retry path so a recovery lands in
/// the same state as a clean boot.
Future<void> _runApp(AppDatabase database) async {
  installErrorLogCapture(database);

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );

  // Decide the start route against the local identity state before the
  // first frame: no profiles yet → onboarding; otherwise dashboard.
  final repository = DriftIdentityRepository(
    database,
    container.read(secureStoreProvider),
  );
  final hasProfiles = await repository.hasAnyProfile();
  final router = buildRouter(
    initialLocation: hasProfiles ? AppRoutes.dashboard : AppRoutes.onboarding,
  );

  // Background backup scheduler: no-op until onboarding exists and a
  // backend is configured (see SyncScheduler).
  container.read(syncSchedulerProvider).start();

  // MCP toolkit (VM-service extensions, debug-only, inert in release) — the
  // package's documented bootstrap pattern. Runs in the same zone as the
  // binding: bootstrapFlutter creates its own inner zone, which trips
  // runApp's debugCheckZone('runApp') zone-mismatch assert.
  MCPToolkitBinding.instance
    ..initialize()
    ..initializeFlutterToolkit();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PharmacyApp(router: router),
    ),
  );
}