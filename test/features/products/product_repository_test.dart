import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/features/products/data/product_repository_impl.dart';

import '../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late DriftProductRepository repository;
  late int pharmacyId;

  setUp(() async {
    db = await createMemoryDb();
    repository = DriftProductRepository(db);
    pharmacyId = await seedPharmacy(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'create stores money as integer minor units and optional expiry',
    () async {
      final product = await repository.create(
        pharmacyId: pharmacyId,
        name: 'باراسيتامول 500',
        costMinor: 1500,
        sellMinor: 2500,
        expiryDate: DateTime(2027, 1, 1),
      );

      expect(product.costMinor, 1500);
      expect(product.sellMinor, 2500);
      expect(product.isActive, isTrue);

      final noExpiry = await repository.create(
        pharmacyId: pharmacyId,
        name: 'فيتامين سي',
        costMinor: 3000,
        sellMinor: 4500,
      );
      expect(noExpiry.expiryDate, isNull);
    },
  );

  test('update changes prices without touching identity fields', () async {
    final product = await repository.create(
      pharmacyId: pharmacyId,
      name: 'باراسيتامول',
      costMinor: 1500,
      sellMinor: 2500,
    );
    await repository.update(product.copyWith(sellMinor: 3000));

    final active = await repository.activeProducts(pharmacyId: pharmacyId);
    expect(active.single.sellMinor, 3000);
  });

  test('deactivate soft-removes: hidden from active, row retained', () async {
    final product = await repository.create(
      pharmacyId: pharmacyId,
      name: 'مضاد حيوي',
      costMinor: 5000,
      sellMinor: 8000,
    );

    await repository.deactivate(product.id);

    final active = await repository.activeProducts(pharmacyId: pharmacyId);
    expect(active, isEmpty);

    final row = await (db.select(
      db.products,
    )..where((t) => t.id.equals(product.id))).getSingle();
    expect(row.isActive, isFalse);
    expect(row.name, 'مضاد حيوي');
  });
}
