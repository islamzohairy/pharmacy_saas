import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/features/identity/data/identity_repository_impl.dart';
import 'package:pharmacy_saas/features/identity/domain/user_role.dart';

class FakeSecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  late AppDatabase db;
  late FakeSecureStore store;
  late DriftIdentityRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = FakeSecureStore();
    repository = DriftIdentityRepository(db, store);
  });

  tearDown(() async {
    await db.close();
  });

  test('first launch: no profiles yet', () async {
    expect(await repository.hasAnyProfile(), isFalse);
  });

  test('creates pharmacy + owner profile atomically, offline', () async {
    final created = await repository.createPharmacyAndOwner(
      pharmacyName: 'صيدلية النور',
      currency: 'EGP',
      ownerDisplayName: 'أم أحمد',
    );

    expect(created.pharmacy.name, 'صيدلية النور');
    expect(created.pharmacy.currency, 'EGP');
    expect(created.owner.role, UserRole.owner);
    expect(created.owner.displayName, 'أم أحمد');
    expect(created.owner.pharmacyId, created.pharmacy.id);
    expect(await repository.hasAnyProfile(), isTrue);
  });

  test('adds a family profile for the shared-shift pattern', () async {
    final created = await repository.createPharmacyAndOwner(
      pharmacyName: 'صيدلية النور',
      currency: 'EGP',
      ownerDisplayName: 'أم أحمد',
    );

    final family = await repository.addFamilyProfile(displayName: 'أبو أحمد');

    expect(family.role, UserRole.family);
    expect(family.pharmacyId, created.pharmacy.id);
    final profiles = await repository.getProfiles();
    expect(profiles, hasLength(2));
  });

  test('last active profile is remembered', () async {
    await repository.createPharmacyAndOwner(
      pharmacyName: 'صيدلية النور',
      currency: 'EGP',
      ownerDisplayName: 'أم أحمد',
    );
    final family = await repository.addFamilyProfile(displayName: 'أبو أحمد');

    expect(await repository.getLastActiveProfile(), isNull);

    await repository.setLastActiveProfile(family);
    final remembered = await repository.getLastActiveProfile();
    expect(remembered?.id, family.id);
  });

  test('PIN: set, verify correct, reject wrong, clear', () async {
    final created = await repository.createPharmacyAndOwner(
      pharmacyName: 'صيدلية النور',
      currency: 'EGP',
      ownerDisplayName: 'أم أحمد',
    );
    final owner = created.owner;

    expect(owner.hasPin, isFalse);
    await repository.setPin(owner, '1234');

    final withPin = await repository.getProfile(owner.id);
    expect(withPin?.hasPin, isTrue);
    expect(await repository.verifyPin(withPin!, '1234'), isTrue);
    expect(await repository.verifyPin(withPin, '9999'), isFalse);

    await repository.clearPin(withPin);
    final cleared = await repository.getProfile(owner.id);
    expect(cleared?.hasPin, isFalse);
  });

  test('PIN hash is never stored in the database', () async {
    final created = await repository.createPharmacyAndOwner(
      pharmacyName: 'صيدلية النور',
      currency: 'EGP',
      ownerDisplayName: 'أم أحمد',
    );
    await repository.setPin(created.owner, '1234');

    // Secure storage holds material; the drift DB only holds the key ref.
    final storedKeys = store.read('pin_hash_${created.owner.id}').toString();
    expect(storedKeys, isNotEmpty);
    final rows = await db.select(db.userProfiles).get();
    expect(rows.single.pinHashRef, 'pin_hash_${created.owner.id}');
    expect(rows.single.pinHashRef, isNot(contains('1234')));
  });

  test(
    'onboarding generates a random remote uuid and a stable device token',
    () async {
      final created = await repository.createPharmacyAndOwner(
        pharmacyName: 'صيدلية النور',
        currency: 'EGP',
        ownerDisplayName: 'أم أحمد',
      );

      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(created.pharmacy.remoteUuid, matches(uuidPattern));
      expect(created.pharmacy.remoteUuid, isNot(RegExp('^0+')));

      final token1 = await repository.getDeviceToken();
      final token2 = await repository.getDeviceToken();
      expect(token1, isNotEmpty);
      expect(token2, token1, reason: 'token must be stable across reads');

      expect(await repository.isDeviceRegistered(), isFalse);
      await repository.markDeviceRegistered();
      expect(await repository.isDeviceRegistered(), isTrue);
    },
  );

  test(
    'wipeLocalIdentity removes profiles, pharmacy, and PIN material',
    () async {
      final created = await repository.createPharmacyAndOwner(
        pharmacyName: 'صيدلية النور',
        currency: 'EGP',
        ownerDisplayName: 'أم أحمد',
      );
      await repository.setPin(created.owner, '1234');
      await repository.setLastActiveProfile(created.owner);
      await repository.markDeviceRegistered();
      final token = await repository.getDeviceToken();

      await repository.wipeLocalIdentity();

      expect(await repository.hasAnyProfile(), isFalse);
      expect(await repository.getLastActiveProfile(), isNull);
      expect(await store.read('pin_hash_${created.owner.id}'), isNull);
      expect(await repository.isDeviceRegistered(), isFalse);
      expect(
        await repository.getDeviceToken(),
        isNot(token),
        reason: 'a fresh identity must get a fresh device token',
      );
    },
  );
}
