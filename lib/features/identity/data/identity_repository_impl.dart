import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/secure_store.dart';
import '../domain/identity_repository.dart';
import '../domain/pharmacy.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';

/// drift-backed identity persistence. Local, offline, always the source
/// of truth for reads.
class DriftIdentityRepository implements IdentityRepository {
  DriftIdentityRepository(this._db, this._secureStore);

  final AppDatabase _db;
  final SecureStore _secureStore;

  static const _lastActiveKey = 'last_active_profile_id';
  static const _pinHashKeyPrefix = 'pin_hash_';

  @override
  Future<bool> hasAnyProfile() async {
    return (await _db.select(_db.userProfiles).get()).isNotEmpty;
  }

  @override
  Future<({Pharmacy pharmacy, UserProfile owner})> createPharmacyAndOwner({
    required String pharmacyName,
    required String currency,
    required String ownerDisplayName,
  }) {
    return _db.transaction(() async {
      final pharmacyId = await _db
          .into(_db.pharmacies)
          .insert(
            PharmaciesCompanion.insert(
              name: pharmacyName.trim(),
              currency: currency.trim(),
            ),
          );
      final ownerId = await _db.into(_db.userProfiles).insert(
        UserProfilesCompanion.insert(
          pharmacyId: pharmacyId,
          role: UserRole.owner.storedValue,
          displayName: ownerDisplayName.trim(),
        ),
      );
      final pharmacy = await (_db.select(_db.pharmacies)
            ..where((t) => t.id.equals(pharmacyId)))
          .getSingle();
      final owner = await (_db.select(_db.userProfiles)
            ..where((t) => t.id.equals(ownerId)))
          .getSingle();
      return (
        pharmacy: pharmacy.toDomain(),
        owner: owner.toDomain(),
      );
    });
  }

  @override
  Future<Pharmacy> getPharmacy() async {
    final row = await (_db.select(_db.pharmacies)..limit(1)).getSingleOrNull();
    if (row == null) {
      throw StateError('No pharmacy on this device yet');
    }
    return row.toDomain();
  }

  @override
  Future<List<UserProfile>> getProfiles() async {
    final rows = await (_db.select(_db.userProfiles)
          ..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
        .get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<UserProfile> addFamilyProfile({required String displayName}) {
    return _db.transaction(() async {
      final pharmacy = await getPharmacy();
      final id = await _db.into(_db.userProfiles).insert(
        UserProfilesCompanion.insert(
          pharmacyId: pharmacy.id,
          role: UserRole.family.storedValue,
          displayName: displayName.trim(),
        ),
      );
      return (await (_db.select(_db.userProfiles)
                ..where((t) => t.id.equals(id)))
              .getSingle())
          .toDomain();
    });
  }

  @override
  Future<UserProfile?> getProfile(int id) async {
    final row = await (_db.select(_db.userProfiles)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> setPin(UserProfile profile, String pin) async {
    final key = _pinKeyFor(profile.id);
    final salt = _randomSalt();
    await _secureStore.write(key, '$salt:${_hashPin(pin, salt)}');
    await (_db.update(_db.userProfiles)
          ..where((t) => t.id.equals(profile.id)))
        .write(UserProfilesCompanion(pinHashRef: Value(key)));
  }

  @override
  Future<bool> verifyPin(UserProfile profile, String pin) async {
    final stored = await _secureStore.read(_pinKeyFor(profile.id));
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _constantTimeEquals(parts[1], _hashPin(pin, parts[0]));
  }

  @override
  Future<void> clearPin(UserProfile profile) async {
    await _secureStore.delete(_pinKeyFor(profile.id));
    await (_db.update(_db.userProfiles)
          ..where((t) => t.id.equals(profile.id)))
        .write(const UserProfilesCompanion(pinHashRef: Value(null)));
  }

  @override
  Future<UserProfile?> getLastActiveProfile() async {
    final rawId = await _secureStore.read(_lastActiveKey);
    if (rawId == null) return null;
    return getProfile(int.tryParse(rawId) ?? -1);
  }

  @override
  Future<void> setLastActiveProfile(UserProfile profile) async {
    await _secureStore.write(_lastActiveKey, profile.id.toString());
  }

  @override
  Future<void> wipeLocalIdentity() async {
    final rows = await _db.select(_db.userProfiles).get();
    await _db.transaction(() async {
      await _db.delete(_db.userProfiles).go();
      await _db.delete(_db.pharmacies).go();
    });
    for (final row in rows) {
      await _secureStore.delete(_pinKeyFor(row.id));
    }
    await _secureStore.delete(_lastActiveKey);
  }

  String _pinKeyFor(int profileId) => '$_pinHashKeyPrefix$profileId';

  String _randomSalt() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// Salted SHA-256 — the PIN is short, so the salt defeats rainbow
  /// precomputation. Hash material lives only in secure storage.
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return base64UrlEncode(sha256.convert(bytes).bytes);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

extension on StoredPharmacy {
  Pharmacy toDomain() => Pharmacy(
    id: id,
    name: name,
    currency: currency,
    createdAt: createdAt,
  );
}

extension on StoredUserProfile {
  UserProfile toDomain() => UserProfile(
    id: id,
    pharmacyId: pharmacyId,
    role: UserRole.fromStoredValue(role),
    displayName: displayName,
    pinHashRef: pinHashRef,
  );
}
