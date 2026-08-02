import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/app_database.dart';
import 'core/data/database_providers.dart';
import 'core/router/app_router.dart';
import 'features/identity/data/identity_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseBootstrap.initializeIfConfigured();

  final database = await openAppDatabase();
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PharmacyApp(router: router),
    ),
  );
}
