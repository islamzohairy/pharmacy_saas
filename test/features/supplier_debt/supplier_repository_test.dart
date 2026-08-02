import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/features/supplier_debt/data/supplier_repository_impl.dart';

import '../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late DriftSupplierRepository repository;
  late int pharmacyId;

  setUp(() async {
    db = await createMemoryDb();
    repository = DriftSupplierRepository(db);
    pharmacyId = await seedPharmacy(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create + list suppliers scoped to the pharmacy', () async {
    await repository.create(pharmacyId: pharmacyId, name: 'مورد الأدوية');
    final other = await seedPharmacy(db, remoteUuid: 'other');
    await repository.create(pharmacyId: other, name: 'مورد آخر');

    final all = await repository.allSuppliers(pharmacyId: pharmacyId);
    expect(all, hasLength(1));
    expect(all.single.name, 'مورد الأدوية');

    final watched = await repository.watchAll(pharmacyId: pharmacyId).first;
    expect(watched, hasLength(1));
  });
}
