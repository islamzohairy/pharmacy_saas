import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'secure_store.dart';

/// Opened once at startup (`main.dart`) and overridden in tests with an
/// in-memory database. All repository providers depend on this.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden at startup (main.dart) or in tests',
  );
});

/// Secure key-value store. Defaults to the real `flutter_secure_storage`
/// implementation; tests override with an in-memory fake.
final secureStoreProvider = Provider<SecureStore>(
  (ref) => const FlutterSecureStore(),
);
