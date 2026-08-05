import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';

/// In-memory [SecureStore] — the DB key (`db_key_v1`) must stay stable
/// across opens of the same file, exactly like the real secure storage.
class FakeSecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// A database that claims schema 99 and throws from its migration — proves
/// a failing `onUpgrade` is caught at the connection boundary and leaves
/// the file untouched.
class ThrowingMigrationAppDatabase extends AppDatabase {
  ThrowingMigrationAppDatabase(super.e);

  @override
  int get schemaVersion => 99;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      throw StateError('simulated migration failure');
    },
  );
}

Future<List<int>> _bytesOf(File file) => file.readAsBytes();

void main() {
  late Directory tempDir;
  late File dbFile;
  late FakeSecureStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pharmacy_db_open_test');
    dbFile = File('${tempDir.path}/pharmacy.sqlite');
    store = FakeSecureStore();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a corrupt database file throws DatabaseOpenException and the file '
      'survives byte-identical (never deleted or recreated)', () async {
    final garbage = Uint8List.fromList(List.generate(4096, (i) => i % 251));
    dbFile.writeAsBytesSync(garbage);

    await expectLater(
      openAppDatabase(secureStore: store, directory: tempDir),
      throwsA(isA<DatabaseOpenException>()),
    );

    expect(dbFile.existsSync(), isTrue, reason: 'the file must never be deleted');
    expect(await _bytesOf(dbFile), garbage,
        reason: 'the file content must never be touched');
  });

  test('retry works after the cause is fixed — the failed open does not '
      'poison the file or the stored key', () async {
    dbFile.writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));

    await expectLater(
      openAppDatabase(secureStore: store, directory: tempDir),
      throwsA(isA<DatabaseOpenException>()),
    );

    dbFile.deleteSync();
    final db = await openAppDatabase(secureStore: store, directory: tempDir);
    await db.close();
    expect(dbFile.existsSync(), isTrue);
  });

  test('a throwing migration surfaces DatabaseOpenException and the file '
      'survives byte-identical', () async {
    final db = await openAppDatabase(secureStore: store, directory: tempDir);
    await db.close();
    final intact = await _bytesOf(dbFile);

    // Reopen the same file with a schema that fails its migration — the
    // connection boundary must catch it without touching the file.
    final key = await store.read('db_key_v1');
    final failing = ThrowingMigrationAppDatabase(
      NativeDatabase(
        dbFile,
        setup: (inner) => inner.execute("PRAGMA key = '$key'"),
      ),
    );

    await expectLater(
      openWithGuard(failing),
      throwsA(isA<DatabaseOpenException>()),
    );

    expect(dbFile.existsSync(), isTrue, reason: 'the file must never be deleted');
    expect(await _bytesOf(dbFile), intact,
        reason: 'a failed migration must not alter the file');
  });
}
