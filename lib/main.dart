import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/app_database.dart';
import 'core/data/database_providers.dart';
import 'core/data/error_log_capture.dart';
import 'core/data/sync/sync_providers.dart';
import 'core/router/app_router.dart';
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

  final database = await openAppDatabase();
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