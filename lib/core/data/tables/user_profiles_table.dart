import 'package:drift/drift.dart';

import 'pharmacies_table.dart';

/// Device-local user profile. `role` is captured but not enforced in P0
/// (DECISIONS.md / ARCHITECTURE.md §Identity).
///
/// `pinHashRef` is a reference to a key inside `flutter_secure_storage`
/// (e.g. `pin_hash_<id>`), never the hash itself — the drift DB never
/// contains PIN material (SECURITY.md).
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `UserProfile` entity.
@DataClassName('StoredUserProfile')
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId =>
      integer().references(Pharmacies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withLength(min: 3, max: 16)();
  TextColumn get displayName => text().withLength(min: 1, max: 100)();
  TextColumn get pinHashRef => text().nullable()();
}
