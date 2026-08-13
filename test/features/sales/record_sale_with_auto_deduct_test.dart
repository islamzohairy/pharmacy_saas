import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/features/inventory/inventory.dart';
import 'package:pharmacy_saas/features/ledger/ledger.dart';
import 'package:pharmacy_saas/features/sales/domain/record_sale_with_auto_deduct.dart';

import '../../support/helpers.dart';

/// The deduct matrix from PLANS/13 §7: every (auto-deduct × tracked)
/// combination, multi-line ordering (D9), negative on-hand tolerance and
/// the D8 failure ordering.
void main() {
  late AppDatabase db;
  late int pharmacyId;
  late int profileId;

  setUp(() async {
    db = await createMemoryDb();
    addTearDown(db.close);
    pharmacyId = await seedPharmacy(db);
    profileId = await seedProfile(db, pharmacyId);
  });

  late LedgerRepository ledger;
  late DriftStockRepository stock;

  group('recordSaleWithAutoDeduct — deduct matrix (PLANS/13 §7)', () {
    Future<void> prepare({
      required bool tracked,
      required int productId,
    }) async {
      ledger = DriftLedgerRepository(db);
      stock = DriftStockRepository(db);
      if (tracked) {
        await seedMovement(
          db,
          pharmacyId,
          productId,
          type: StockMovementType.initial,
          quantity: 10,
        );
      }
    }

    Future<List<StockMovement>> movementsOf(int productId) {
      return stock.getMovements(pharmacyId: pharmacyId, productId: productId);
    }

    test('tracked × auto-deduct ON → sale plus one attributed stock_out', () async {
      final productId = await seedProduct(db, pharmacyId);
      await prepare(tracked: true, productId: productId);

      await recordSaleWithAutoDeduct(
        ledger,
        stock,
        autoDeduct: true,
        isTracked: true,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 2,
        sellMinor: 2550,
        profileId: profileId,
      );

      final movements = await movementsOf(productId);
      expect(movements, hasLength(2));
      expect(movements.last.type, StockMovementType.stockOut);
      expect(movements.last.quantity, -2);
      expect(movements.last.profileId, profileId);

      final entries = await ledger.unsyncedEntries(pharmacyId: pharmacyId);
      expect(entries, hasLength(1));
    });

    test('tracked × OFF → sale only, movements untouched', () async {
      final productId = await seedProduct(db, pharmacyId);
      await prepare(tracked: true, productId: productId);

      await recordSaleWithAutoDeduct(
        ledger,
        stock,
        autoDeduct: false,
        isTracked: true,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 2,
        sellMinor: 2550,
        profileId: profileId,
      );

      final movements = await movementsOf(productId);
      expect(movements, hasLength(1));
      expect(movements.single.type, StockMovementType.initial);
      expect((await ledger.unsyncedEntries(pharmacyId: pharmacyId)), hasLength(1));
    });

    test('untracked × ON → sale only — never deducted (D6)', () async {
      final productId = await seedProduct(db, pharmacyId);
      await prepare(tracked: false, productId: productId);

      await recordSaleWithAutoDeduct(
        ledger,
        stock,
        autoDeduct: true,
        isTracked: false,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 3,
        sellMinor: 2550,
        profileId: profileId,
      );

      expect(await movementsOf(productId), isEmpty);
      expect((await ledger.unsyncedEntries(pharmacyId: pharmacyId)), hasLength(1));
    });

    test('untracked × OFF → sale only', () async {
      final productId = await seedProduct(db, pharmacyId);
      await prepare(tracked: false, productId: productId);

      await recordSaleWithAutoDeduct(
        ledger,
        stock,
        autoDeduct: false,
        isTracked: false,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 3,
        sellMinor: 2550,
      );

      expect(await movementsOf(productId), isEmpty);
      expect((await ledger.unsyncedEntries(pharmacyId: pharmacyId)), hasLength(1));
    });

    test('multi-line cart → one movement per tracked line (D9)', () async {
      final trackedProduct = await seedProduct(db, pharmacyId);
      final untrackedProduct = await seedProduct(db, pharmacyId, name: 'Panadol');
      await prepare(tracked: true, productId: trackedProduct);

      await recordSaleWithAutoDeduct(
        ledger,
        stock,
        autoDeduct: true,
        isTracked: true,
        pharmacyId: pharmacyId,
        productId: trackedProduct,
        quantity: 1,
        sellMinor: 2550,
      );
      await recordSaleWithAutoDeduct(
        ledger,
        stock,
        autoDeduct: true,
        isTracked: false,
        pharmacyId: pharmacyId,
        productId: untrackedProduct,
        quantity: 4,
        sellMinor: 3000,
      );

      final trackedMovements = await movementsOf(trackedProduct);
      expect(trackedMovements, hasLength(2));
      expect(trackedMovements.last.quantity, -1);
      expect(await movementsOf(untrackedProduct), isEmpty);
      expect((await ledger.unsyncedEntries(pharmacyId: pharmacyId)), hasLength(2));
    });

    test('selling below zero is allowed — deduction never clamps', () async {
      final productId = await seedProduct(db, pharmacyId);
      await prepare(tracked: true, productId: productId);

      await recordSaleWithAutoDeduct(
        ledger,
        stock,
        autoDeduct: true,
        isTracked: true,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 15,
        sellMinor: 2550,
      );

      final movements = await movementsOf(productId);
      expect(movements, hasLength(2));
      expect(movements.last.quantity, -15);
      expect((await ledger.unsyncedEntries(pharmacyId: pharmacyId)), hasLength(1));
    });
  });

  group('D8 ordering — stock failure never blocks the sale', () {
    test('stock-write failure → sale stands and failure callback fires',
        () async {
      final productId = await seedProduct(db, pharmacyId);
      ledger = DriftLedgerRepository(db);
      var reported = 0;

      await recordSaleWithAutoDeduct(
        ledger,
        _ThrowingStockRepository(),
        autoDeduct: true,
        isTracked: true,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 2,
        sellMinor: 2550,
        onStockFailure: () async => reported++,
      );

      final entries = await ledger.unsyncedEntries(pharmacyId: pharmacyId);
      expect(entries, hasLength(1));
      expect(entries.single.amountMinor, 5100);
      expect(reported, 1);
    });

    test('a failure inside the failure-callback itself is swallowed too',
        () async {
      final productId = await seedProduct(db, pharmacyId);
      ledger = DriftLedgerRepository(db);

      await recordSaleWithAutoDeduct(
        ledger,
        _ThrowingStockRepository(),
        autoDeduct: true,
        isTracked: true,
        pharmacyId: pharmacyId,
        productId: productId,
        quantity: 1,
        sellMinor: 2550,
        onStockFailure: () async => throw StateError('log broken'),
      );

      // The sale is still complete and the call does not throw (Plan 09).
      expect(await ledger.unsyncedEntries(pharmacyId: pharmacyId), hasLength(1));
    });
  });
}

/// Minimal failing stand-in: every stock write throws, everything else is
/// unreachable for the coordinator path under test.
class _ThrowingStockRepository implements StockRepository {
  @override
  Future<StockMovement> recordMovement({
    required int pharmacyId,
    required int productId,
    required StockMovementType type,
    required int quantity,
    required DateTime occurredAt,
    int? profileId,
    String? note,
  }) async {
    throw StateError('stock write failed');
  }

  @override
  Stream<Map<int, int>> watchAllOnHand({required int pharmacyId}) =>
      Stream.value(const {});

  @override
  Future<Map<int, int>> allOnHand({required int pharmacyId}) async => const {};

  @override
  Stream<int> watchOnHand({required int pharmacyId, required int productId}) =>
      Stream.value(0);

  @override
  Future<List<StockMovement>> getMovements({
    required int pharmacyId,
    required int productId,
  }) async => [];
}