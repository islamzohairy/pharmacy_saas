import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'secure_store.dart';
import 'tables/customers_table.dart';
import 'tables/error_log_table.dart';
import 'tables/ledger_entries_table.dart';
import 'tables/pharmacies_table.dart';
import 'tables/products_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/sync_quarantine_table.dart';
import 'tables/user_profiles_table.dart';

part 'app_database.g.dart';

/// Local source of truth. Encrypted at rest via the SQLCipher build of
/// sqlite3 (see the `hooks` section in pubspec.yaml).
///
/// Schema version 1 (foundation) had no tables; version 2 adds identity
/// (`pharmacies`, `user_profiles`); version 3 adds the plan-03 entities
/// (`products`, `suppliers`, `customers`, `ledger_entries`); version 4
/// adds the local error log (`error_log_entries`, PLANS/09); version 5
/// renames `cashDraw` → `expense` with a `category` column and adds
/// compliance-prep fields to `pharmacies` (PLANS/10); version 6 adds the
/// sync-failure quarantine (`sync_quarantine_entries`, PLANS/11-H Phase
/// 2). The append-only ledger rule applies to the schema added in
/// version 3.
@DriftDatabase(
  tables: [
    Pharmacies,
    UserProfiles,
    Products,
    Suppliers,
    Customers,
    LedgerEntries,
    ErrorLogEntries,
    SyncQuarantineEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(pharmacies);
      await m.createTable(userProfiles);
      await m.createTable(products);
      await m.createTable(suppliers);
      await m.createTable(customers);
      await m.createTable(ledgerEntries);
      await m.createTable(errorLogEntries);
      await m.createTable(syncQuarantineEntries);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(pharmacies);
        await m.createTable(userProfiles);
      }
      if (from < 3) {
        await m.createTable(products);
        await m.createTable(suppliers);
        await m.createTable(customers);
        await m.createTable(ledgerEntries);
      }
      if (from < 4) {
        await m.createTable(errorLogEntries);
      }
      if (from < 5) {
        await m.addColumn(ledgerEntries, ledgerEntries.category);
        await m.addColumn(pharmacies, pharmacies.taxRegistrationNumber);
        await m.addColumn(pharmacies, pharmacies.legalBusinessName);
        // One-time schema-correction backfill: the pre-v5 local rows used
        // the `cashDraw` enum name as their stored type. The new enum
        // member is `expense` and drift serializes by name, so without
        // this UPDATE existing draws would fail to deserialize. This is a
        // migration, not an app-level ledger edit — it does not go
        // through LedgerRepository and the append-only rule governs the
        // normal write surface only (PLANS/10 Phase 1). Existing draws
        // become owner-draw expenses (their only valid meaning).
        await customStatement(
          "UPDATE ledger_entries SET type = 'expense', "
          "category = 'ownerDraw' WHERE type = 'cashDraw'",
        );
      }
      if (from < 6) {
        await m.createTable(syncQuarantineEntries);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Thrown when the encrypted database cannot be opened — corrupt file,
/// lost/rotated encryption key, or a failing migration. Carries the
/// underlying cause for the user-facing report.
///
/// The on-disk file is NEVER touched by the open path: no delete, no move,
/// no recreate (PLANS/11 §4.3 — a pilot device cannot be bricked by a
/// failed open). The only data-destroying path in the app is the explicit
/// user-initiated identity wipe (forgot-PIN flow).
class DatabaseOpenException implements Exception {
  const DatabaseOpenException(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'DatabaseOpenException: $cause';
}

/// Opens the encrypted on-disk database.
///
/// The encryption key is generated once and stored via [SecureStore] —
/// never in the database file itself, never hardcoded in source.
///
/// [directory] is injectable for tests (defaults to the app documents
/// directory).
Future<AppDatabase> openAppDatabase({
  SecureStore? secureStore,
  Directory? directory,
}) async {
  final store = secureStore ?? const FlutterSecureStore();
  final key = await _obtainDatabaseKey(store);
  final dir = directory ?? await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'pharmacy.sqlite'));

  final executor = NativeDatabase.createInBackground(
    file,
    setup: (db) => db.execute("PRAGMA key = '$key'"),
  );
  return openWithGuard(AppDatabase(executor));
}

/// Forces the database open — including any pending migrations — to run at
/// the connection boundary instead of drift's lazy first-query open, and
/// converts any failure into [DatabaseOpenException].
///
/// Why: drift opens on first query, which would surface a corrupt-file or
/// migration failure from inside the first screen's provider tree. Forcing
/// it here means `main.dart` can catch it and render the non-destructive
/// fatal screen with a copy-report + user-triggered retry (PLANS/11 §4.3).
Future<T> openWithGuard<T extends AppDatabase>(T database) async {
  try {
    await database.customSelect('SELECT 1').getSingle();
    return database;
  } catch (error, stack) {
    throw DatabaseOpenException(error, stack);
  }
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
