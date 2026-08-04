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
  static const _deviceTokenKey = 'device_token_v1';
  static const _deviceRegisteredKey = 'device_registered_v1';

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
              remoteUuid: Value(_randomUuidV4()),
            ),
          );
      final ownerId = await _db
          .into(_db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              pharmacyId: pharmacyId,
              role: UserRole.owner.storedValue,
              displayName: ownerDisplayName.trim(),
            ),
          );
      final pharmacy = await (_db.select(
        _db.pharmacies,
      )..where((t) => t.id.equals(pharmacyId))).getSingle();
      final owner = await (_db.select(
        _db.userProfiles,
      )..where((t) => t.id.equals(ownerId))).getSingle();
      await getDeviceToken();
      return (pharmacy: pharmacy.toDomain(), owner: owner.toDomain());
    });
  }

  @override
  Future<String> getDeviceToken() async {
    final existing = await _secureStore.read(_deviceTokenKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final token = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _secureStore.write(_deviceTokenKey, token);
    return token;
  }

  @override
  Future<bool> isDeviceRegistered() async {
    return await _secureStore.read(_deviceRegisteredKey) == '1';
  }

  @override
  Future<void> markDeviceRegistered() async {
    await _secureStore.write(_deviceRegisteredKey, '1');
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
  Future<Pharmacy> updatePharmacySettings({
    required String? taxRegistrationNumber,
    required String? legalBusinessName,
  }) {
    return _db.transaction(() async {
      final pharmacy = await getPharmacy();
      await (_db.update(_db.pharmacies)..where((t) => t.id.equals(pharmacy.id)))
          .write(
            PharmaciesCompanion(
              taxRegistrationNumber: Value(
                taxRegistrationNumber?.trim(),
              ),
              legalBusinessName: Value(legalBusinessName?.trim()),
            ),
          );
      return (_db.select(
        _db.pharmacies,
      )..where((t) => t.id.equals(pharmacy.id)))
          .getSingle()
          .then((row) => row.toDomain());
    });
  }

  @override
  Future<List<UserProfile>> getProfiles() async {
    final rows = await (_db.select(
      _db.userProfiles,
    )..orderBy([(t) => OrderingTerm.asc(t.displayName)])).get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<UserProfile> addFamilyProfile({required String displayName}) {
    return _db.transaction(() async {
      final pharmacy = await getPharmacy();
      final id = await _db
          .into(_db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              pharmacyId: pharmacy.id,
              role: UserRole.family.storedValue,
              displayName: displayName.trim(),
            ),
          );
      return (await (_db.select(
        _db.userProfiles,
      )..where((t) => t.id.equals(id))).getSingle()).toDomain();
    });
  }

  @override
  Future<UserProfile?> getProfile(int id) async {
    final row = await (_db.select(
      _db.userProfiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> setPin(UserProfile profile, String pin) async {
    final key = _pinKeyFor(profile.id);
    final salt = _randomSalt();
    await _secureStore.write(key, '$salt:${_hashPin(pin, salt)}');
    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(profile.id)))
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
    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(profile.id)))
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
    await _secureStore.delete(_deviceTokenKey);
    await _secureStore.delete(_deviceRegisteredKey);
  }

  String _pinKeyFor(int profileId) => '$_pinHashKeyPrefix$profileId';

  /// RFC 4122 version 4 UUID from [Random.secure] — the remote tenant
  /// binding key must be unguessable across tenants.
  String _randomUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  String _randomSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
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
    remoteUuid: remoteUuid,
    taxRegistrationNumber: taxRegistrationNumber,
    legalBusinessName: legalBusinessName,
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
