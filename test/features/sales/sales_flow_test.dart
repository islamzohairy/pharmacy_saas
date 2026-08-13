import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/error_log_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';
import 'package:pharmacy_saas/features/inventory/inventory.dart';
import 'package:pharmacy_saas/features/ledger/ledger.dart';

import '../../support/helpers.dart';

class FakeSecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Failing stock repository for the D8 widget path: the sale must succeed
/// and log an error, never fail the whole flow. [onHand] mirrors the
/// real aggregate so tracked products are recognized as tracked.
class _ThrowingStockRepository implements StockRepository {
  _ThrowingStockRepository({this.onHand = const {}});

  final Map<int, int> onHand;

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
      Stream.value(onHand);

  @override
  Future<Map<int, int>> allOnHand({required int pharmacyId}) async => onHand;

  @override
  Stream<int> watchOnHand({required int pharmacyId, required int productId}) =>
      Stream.value(0);

  @override
  Future<List<StockMovement>> getMovements({
    required int pharmacyId,
    required int productId,
  }) async => [];
}

/// Pumps the full app on a memory DB with one seeded pharmacy, an active
/// profile and one seeded product.
Future<ProviderContainer> pumpSalesApp(
  WidgetTester tester,
  AppDatabase db, {
  required int profileId,
  List<Override> overrides = const [],
}) async {
  final store = FakeSecureStore();
  await store.write('last_active_profile_id', '$profileId');
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      secureStoreProvider.overrideWithValue(store),
      ...overrides,
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PharmacyApp(router: buildRouter(initialLocation: AppRoutes.sales)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

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

  group('SalesScreen', () {
    testWidgets('empty state offers a path to the products screen', (
      tester,
    ) async {
      await pumpSalesApp(tester, db, profileId: profileId);

      expect(find.text('لا توجد منتجات بعد'), findsOneWidget);
      await tester.tap(find.text('الذهاب إلى المنتجات'));
      await tester.pumpAndSettle();
      expect(find.text('المنتجات'), findsOneWidget);
    });

    testWidgets('adds a line, totals it and writes one attributed sale', (
      tester,
    ) async {
      final productId = await seedProduct(db, pharmacyId);
      final container = await pumpSalesApp(tester, db, profileId: profileId);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pump();
      // Line tile and running total both read ٢٥٫٥٠ with one unit.
      expect(find.textContaining('الإجمالي: ٢٥٫٥٠ ج.م'), findsNWidgets(2));

      await tester.tap(find.byTooltip('زيادة الكمية'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('الإجمالي: ٥١٫٠٠ ج.م'), findsNWidgets(2));
      expect(find.textContaining('الإجمالي: ٢٥٫٥٠ ج.م'), findsNothing);

      await tester.tap(find.text('تأكيد البيع'));
      await tester.pumpAndSettle();

      expect(find.text('تم تسجيل البيع'), findsOneWidget);
      final entries = await container
          .read(ledgerRepositoryProvider)
          .unsyncedEntries(pharmacyId: pharmacyId);
      expect(entries, hasLength(1));
      expect(entries.single.type, LedgerEntryType.sale);
      expect(entries.single.amountMinor, 2550 * 2);
      expect(entries.single.productId, productId);
      expect(entries.single.profileId, profileId);
    });

    testWidgets('reduces quantity to zero removes the line', (tester) async {
      await seedProduct(db, pharmacyId);
      await pumpSalesApp(tester, db, profileId: profileId);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pump();
      expect(find.byTooltip('إزالة الصنف'), findsOneWidget);
      await tester.tap(find.byTooltip('تقليل الكمية'));
      await tester.pump();

      // The cart line is gone (only the picker tile remains) and the
      // confirm button is disabled again.
      expect(find.byTooltip('إزالة الصنف'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'تأكيد البيع'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('search filters the product picker, case-insensitive', (
      tester,
    ) async {
      await seedProduct(db, pharmacyId, name: 'باراسيتامول 500');
      await seedProduct(db, pharmacyId, name: 'Panadol');
      await pumpSalesApp(tester, db, profileId: profileId);

      // Latin names match regardless of case.
      await tester.enterText(find.byType(TextField), 'panadol');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Panadol'), findsOneWidget);
      expect(find.text('باراسيتامول 500'), findsNothing);

      // Arabic names match exactly.
      await tester.enterText(find.byType(TextField), 'باراسيتامول');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'باراسيتامول 500'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Panadol'), findsNothing);
    });

    testWidgets(
        'tracked sale with auto-deduct ON posts one attributed stock_out',
        (tester) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(
        db,
        pharmacyId,
        productId,
        type: StockMovementType.initial,
        quantity: 10,
      );
      final container = await pumpSalesApp(tester, db, profileId: profileId);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pump();
      await tester.tap(find.text('تأكيد البيع'));
      await tester.pumpAndSettle();
      expect(find.text('تم تسجيل البيع'), findsOneWidget);

      final movements = await container
          .read(stockRepositoryProvider)
          .getMovements(pharmacyId: pharmacyId, productId: productId);
      expect(movements, hasLength(2));
      expect(movements.last.type, StockMovementType.stockOut);
      expect(movements.last.quantity, -1);
      expect(movements.last.profileId, profileId);
    });

    testWidgets('auto-deduct OFF posts no movement', (tester) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(
        db,
        pharmacyId,
        productId,
        type: StockMovementType.initial,
        quantity: 10,
      );
      await (db.update(db.pharmacies)..where((t) => t.id.equals(pharmacyId)))
          .write(const PharmaciesCompanion(autoDeductStock: Value(false)));
      final container = await pumpSalesApp(tester, db, profileId: profileId);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pump();
      await tester.tap(find.text('تأكيد البيع'));
      await tester.pumpAndSettle();

      final movements = await container
          .read(stockRepositoryProvider)
          .getMovements(pharmacyId: pharmacyId, productId: productId);
      expect(movements, hasLength(1));
      expect(movements.single.type, StockMovementType.initial);
    });

    testWidgets('untracked product with auto-deduct ON is never deducted (D6)',
        (tester) async {
      final productId = await seedProduct(db, pharmacyId);
      final container = await pumpSalesApp(tester, db, profileId: profileId);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pump();
      await tester.tap(find.text('تأكيد البيع'));
      await tester.pumpAndSettle();

      final movements = await container
          .read(stockRepositoryProvider)
          .getMovements(pharmacyId: pharmacyId, productId: productId);
      expect(movements, isEmpty);
    });

    testWidgets('two-line cart deducts only the tracked line (D9)', (
      tester,
    ) async {
      final trackedId = await seedProduct(db, pharmacyId);
      final untrackedId = await seedProduct(db, pharmacyId, name: 'Panadol');
      await seedMovement(
        db,
        pharmacyId,
        trackedId,
        type: StockMovementType.initial,
        quantity: 5,
      );
      final container = await pumpSalesApp(tester, db, profileId: profileId);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pump();
      await tester.tap(find.text('Panadol'));
      await tester.pump();
      await tester.tap(find.text('تأكيد البيع'));
      await tester.pumpAndSettle();

      final stock = container.read(stockRepositoryProvider);
      final tracked = await stock.getMovements(
        pharmacyId: pharmacyId,
        productId: trackedId,
      );
      expect(tracked, hasLength(2));
      expect(tracked.last.quantity, -1);
      expect(
        await stock.getMovements(pharmacyId: pharmacyId, productId: untrackedId),
        isEmpty,
      );
    });

    testWidgets(
        'stock-write failure keeps the sale and appends an error-log entry',
        (tester) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(
        db,
        pharmacyId,
        productId,
        type: StockMovementType.initial,
        quantity: 10,
      );
      final container = await pumpSalesApp(
        tester,
        db,
        profileId: profileId,
        overrides: [
          stockRepositoryProvider.overrideWithValue(
            _ThrowingStockRepository(onHand: {productId: 10}),
          ),
        ],
      );

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pump();
      await tester.tap(find.text('تأكيد البيع'));
      await tester.pumpAndSettle();

      // Sale succeeded and the failure surfaced only in the error log (D8).
      expect(find.text('تم تسجيل البيع'), findsOneWidget);
      final entries = await container
          .read(ledgerRepositoryProvider)
          .unsyncedEntries(pharmacyId: pharmacyId);
      expect(entries, hasLength(1));
      final logged = await container
          .read(errorLogRepositoryProvider)
          .unreportedEntries();
      expect(logged, hasLength(1));
      expect(logged.single.errorType, 'AutoDeductStock');
    });
  });
}
