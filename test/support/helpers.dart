import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';

/// In-memory drift database — no SQLCipher needed in tests.
Future<AppDatabase> createMemoryDb() async {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a tenant row and returns its id.
Future<int> seedPharmacy(AppDatabase db, {String? remoteUuid}) async {
  return db
      .into(db.pharmacies)
      .insert(
        PharmaciesCompanion.insert(
          name: 'صيدلية النور',
          currency: 'EGP',
          remoteUuid: Value(remoteUuid ?? 'test-uuid-0000000000000000'),
        ),
      );
}

/// Seeds a profile row (the ledger's `profile_id` FK target) and returns
/// its id.
Future<int> seedProfile(AppDatabase db, int pharmacyId) {
  return db
      .into(db.userProfiles)
      .insert(
        UserProfilesCompanion.insert(
          pharmacyId: pharmacyId,
          role: 'owner',
          displayName: 'أم أحمد',
        ),
      );
}

/// Seeds an active product row and returns its id.
Future<int> seedProduct(
  AppDatabase db,
  int pharmacyId, {
  String? name,
  int costMinor = 2000,
  int sellMinor = 2550,
}) {
  return db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          pharmacyId: pharmacyId,
          name: name ?? 'باراسيتامول 500',
          costMinor: costMinor,
          sellMinor: sellMinor,
        ),
      );
}
