import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Local source of truth. Encrypted at rest via the SQLCipher build of
/// sqlite3 (see the `hooks` section in pubspec.yaml).
///
/// Schema is deliberately empty — tables arrive with PLANS/03. The
/// append-only ledger rule applies to the schema added there, not here.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Opens the encrypted on-disk database.
///
/// The encryption key is generated once and stored in
/// `flutter_secure_storage` — never in the database file itself, never
/// hardcoded in source.
Future<AppDatabase> openAppDatabase() async {
  final key = await _obtainDatabaseKey();
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, 'pharmacy.sqlite'));

  final executor = NativeDatabase.createInBackground(
    file,
    setup: (db) => db.execute("PRAGMA key = '$key'"),
  );
  return AppDatabase(executor);
}

const _secureStorage = FlutterSecureStorage();
const _databaseKeyName = 'db_key_v1';

Future<String> _obtainDatabaseKey() async {
  final existing = await _secureStorage.read(key: _databaseKeyName);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = base64UrlEncode(bytes);
  await _secureStorage.write(key: _databaseKeyName, value: key);
  return key;
}
