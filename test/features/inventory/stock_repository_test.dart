import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/tables/stock_movement_type.dart';
import 'package:pharmacy_saas/features/inventory/data/stock_repository_impl.dart';

import '../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late DriftStockRepository repository;
  late int pharmacyA;
  late int pharmacyB;

  setUp(() async {
    db = await createMemoryDb();
    repository = DriftStockRepository(db);
    pharmacyA = await seedPharmacy(db);
    pharmacyB = await seedPharmacy(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('recordMovement appends and returns the movement with attribution',
      () async {
    final productId = await seedProduct(db, pharmacyA);
    final profileId = await seedProfile(db, pharmacyA);

    final movement = await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: productId,
      type: StockMovementType.initial,
      quantity: 12,
      occurredAt: DateTime(2026, 8, 1, 10),
      profileId: profileId,
      note: 'جرد بداية',
    );

    expect(movement.productId, productId);
    expect(movement.type, StockMovementType.initial);
    expect(movement.quantity, 12);
    expect(movement.profileId, profileId);
    expect(movement.note, 'جرد بداية');

    final history = await repository.getMovements(
      pharmacyId: pharmacyA,
      productId: productId,
    );
    expect(history, hasLength(1));
    expect(history.single.id, movement.id);
  });

  test(
    'per-pharmacy isolation: pharmacy A never sees B\'s movements',
    () async {
      final productA = await seedProduct(db, pharmacyA);
      final productB = await seedProduct(db, pharmacyB);

      await repository.recordMovement(
        pharmacyId: pharmacyA,
        productId: productA,
        type: StockMovementType.initial,
        quantity: 7,
        occurredAt: DateTime(2026, 8, 1),
      );
      await repository.recordMovement(
        pharmacyId: pharmacyB,
        productId: productB,
        type: StockMovementType.initial,
        quantity: 99,
        occurredAt: DateTime(2026, 8, 1),
      );

      final onHandA = await repository
          .watchAllOnHand(pharmacyId: pharmacyA)
          .first;
      expect(onHandA, {productA: 7});

      final onHandB = await repository
          .watchAllOnHand(pharmacyId: pharmacyB)
          .first;
      expect(onHandB, {productB: 99});

      final historyA = await repository.getMovements(
        pharmacyId: pharmacyA,
        productId: productA,
      );
      expect(historyA, hasLength(1));
      expect(historyA.single.quantity, 7);
    },
  );

  test('watchAllOnHand aggregates per product in one map (no N+1)', () async {
    final p1 = await seedProduct(db, pharmacyA);
    final p2 = await seedProduct(db, pharmacyA);

    await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: p1,
      type: StockMovementType.initial,
      quantity: 10,
      occurredAt: DateTime(2026, 8, 1, 9),
    );
    await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: p1,
      type: StockMovementType.stockIn,
      quantity: 5,
      occurredAt: DateTime(2026, 8, 1, 10),
    );
    await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: p2,
      type: StockMovementType.initial,
      quantity: 3,
      occurredAt: DateTime(2026, 8, 1, 11),
    );

    final onHand = await repository
        .watchAllOnHand(pharmacyId: pharmacyA)
        .first;
    expect(onHand, {p1: 15, p2: 3});
  });

  test('watchAllOnHand emits on append and drops products without movements',
      () async {
    final productId = await seedProduct(db, pharmacyA);
    final emitted = Completer<Map<int, int>>();
    final subscription = repository
        .watchAllOnHand(pharmacyId: pharmacyA)
        .listen((map) {
      if (map.containsKey(productId) && !emitted.isCompleted) {
        emitted.complete(map);
      }
    });

    await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: productId,
      type: StockMovementType.initial,
      quantity: 4,
      occurredAt: DateTime(2026, 8, 1),
    );
    // A product with zero movements never appears in the map.
    final onHand = await emitted.future
        .timeout(const Duration(seconds: 2));
    expect(onHand, {productId: 4});

    await subscription.cancel();
  });

  test('watchOnHand streams the live aggregate, unclamped', () async {
    final productId = await seedProduct(db, pharmacyA);
    final values = <int>[];
    final emitted = Completer<int>();
    final subscription = repository
        .watchOnHand(pharmacyId: pharmacyA, productId: productId)
        .listen((value) {
      values.add(value);
      if (value == -6 && !emitted.isCompleted) emitted.complete(value);
    });

    await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: productId,
      type: StockMovementType.initial,
      quantity: 3,
      occurredAt: DateTime(2026, 8, 1),
    );
    await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: productId,
      type: StockMovementType.stockOut,
      quantity: -9,
      occurredAt: DateTime(2026, 8, 2),
    );

    // Negative on-hand passes through — never clamped (D3).
    expect(await emitted.future.timeout(const Duration(seconds: 2)), -6);
    expect(values.last, -6);

    await subscription.cancel();
  });

  test('getMovements returns the ordered history, oldest first', () async {
    final productId = await seedProduct(db, pharmacyA);
    final first = await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: productId,
      type: StockMovementType.initial,
      quantity: 10,
      occurredAt: DateTime(2026, 8, 1, 8),
    );
    final second = await repository.recordMovement(
      pharmacyId: pharmacyA,
      productId: productId,
      type: StockMovementType.stockIn,
      quantity: 5,
      occurredAt: DateTime(2026, 8, 3, 9),
    );

    final history = await repository.getMovements(
      pharmacyId: pharmacyA,
      productId: productId,
    );
    expect(history.map((m) => m.id), [first.id, second.id]);
  });
}