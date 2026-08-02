import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'secure_store.dart';
import 'tables/pharmacies_table.dart';
import 'tables/user_profiles_table.dart';

part 'app_database.g.dart';

/// Local source of truth. Encrypted at rest via the SQLCipher build of
/// sqlite3 (see the `hooks` section in pubspec.yaml).
///
/// Schema version 1 (foundation) had no tables; version 2 adds identity
/// (`pharmacies`, `user_profiles`). Plan 03 adds the remaining entities —
/// the append-only ledger rule applies to the schema added there.
@DriftDatabase(tables: [Pharmacies, UserProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(pharmacies);
      await m.createTable(userProfiles);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(pharmacies);
        await m.createTable(userProfiles);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the encrypted on-disk database.
///
/// The encryption key is generated once and stored via [SecureStore] —
/// never in the database file itself, never hardcoded in source.
Future<AppDatabase> openAppDatabase({SecureStore? secureStore}) async {
  final store = secureStore ?? const FlutterSecureStore();
  final key = await _obtainDatabaseKey(store);
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, 'pharmacy.sqlite'));

  final executor = NativeDatabase.createInBackground(
    file,
    setup: (db) => db.execute("PRAGMA key = '$key'"),
  );
  return AppDatabase(executor);
}

const _databaseKeyName = 'db_key_v1';

Future<String> _obtainDatabaseKey(SecureStore store) async {
  final existing = await store.read(_databaseKeyName);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = base64UrlEncode(bytes);
  await store.write(_databaseKeyName, key);
  return key;
}
