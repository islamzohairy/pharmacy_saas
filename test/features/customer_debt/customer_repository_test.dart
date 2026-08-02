import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/features/customer_debt/data/customer_repository_impl.dart';

import '../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late DriftCustomerRepository repository;
  late int pharmacyId;

  setUp(() async {
    db = await createMemoryDb();
    repository = DriftCustomerRepository(db);
    pharmacyId = await seedPharmacy(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create + list customers scoped to the pharmacy', () async {
    await repository.create(pharmacyId: pharmacyId, name: 'عميل بالآجل');
    final other = await seedPharmacy(db, remoteUuid: 'other');
    await repository.create(pharmacyId: other, name: 'عميل آخر');

    final all = await repository.allCustomers(pharmacyId: pharmacyId);
    expect(all, hasLength(1));
    expect(all.single.name, 'عميل بالآجل');

    final watched = await repository.watchAll(pharmacyId: pharmacyId).first;
    expect(watched, hasLength(1));
  });
}
