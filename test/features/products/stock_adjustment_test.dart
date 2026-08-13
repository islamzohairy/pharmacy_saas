import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/data/tables/stock_movement_type.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';
import 'package:pharmacy_saas/features/inventory/inventory.dart';

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

/// Pumps the full app on a memory DB with one seeded pharmacy, an active
/// profile and the products screen as the initial route.
Future<ProviderContainer> pumpProductsApp(
  WidgetTester tester,
  AppDatabase db, {
  required int profileId,
}) async {
  final store = FakeSecureStore();
  await store.write('last_active_profile_id', '$profileId');
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      secureStoreProvider.overrideWithValue(store),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PharmacyApp(
        router: buildRouter(initialLocation: AppRoutes.products),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Opens the row action sheet for the seeded product and taps the stock
/// adjustment entry.
Future<void> openAdjustmentSheet(WidgetTester tester) async {
  await tester.tap(find.text('باراسيتامول 500'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('المخزون: إضافة / تصحيح'));
  await tester.pumpAndSettle();
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

  Future<List<StoredStockMovement>> movements() {
    return db.select(db.stockMovements).get();
  }

  group('product-row action sheet (PLANS/13 §5.3)', () {
    testWidgets('row tap opens the sheet with both actions and a cancel', (
      tester,
    ) async {
      await seedProduct(db, pharmacyId);
      await pumpProductsApp(tester, db, profileId: profileId);

      // The chevron is the visible tappable cue (staff review item).
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pumpAndSettle();

      expect(find.text('المخزون: إضافة / تصحيح'), findsOneWidget);
      expect(find.text('تعديل بيانات المنتج'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('المخزون: إضافة / تصحيح'), findsNothing);
      // Still on the products list.
      expect(find.text('باراسيتامول 500'), findsOneWidget);
    });

    testWidgets('sheet entry works for an untracked product too', (
      tester,
    ) async {
      await seedProduct(db, pharmacyId);
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.text('باراسيتامول 500'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المخزون: إضافة / تصحيح'));
      await tester.pumpAndSettle();

      // The sheet shows the neutral dash, not a false zero.
      expect(find.text('المخزون الحالي: —'), findsOneWidget);
    });
  });

  group('StockAdjustmentSheet — add mode', () {
    testWidgets('previews the new total and posts one attributed stock_in', (
      tester,
    ) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(db, pharmacyId, productId, quantity: 15);
      await pumpProductsApp(tester, db, profileId: profileId);

      await openAdjustmentSheet(tester);
      expect(find.text('المخزون الحالي: ١٥'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '5');
      await tester.pump();
      expect(find.text('بعد الإضافة: ٢٠'), findsOneWidget);

      await tester.tap(find.text('تحديث المخزون'));
      await tester.pumpAndSettle();

      // Sheet dismissed, list updated live via the existing stream.
      expect(find.text('تحديث المخزون'), findsNothing);
      expect(find.text('المخزون: ٢٠'), findsOneWidget);

      final rows = await movements();
      expect(rows, hasLength(2));
      expect(rows.last.type, StockMovementType.stockIn);
      expect(rows.last.quantity, 5);
      expect(rows.last.profileId, profileId);
    });

    testWidgets('Arabic-Indic digits parse through the shared path', (
      tester,
    ) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(db, pharmacyId, productId, quantity: 15);
      await pumpProductsApp(tester, db, profileId: profileId);

      await openAdjustmentSheet(tester);
      await tester.enterText(find.byType(TextField).first, '٥');
      await tester.pump();
      expect(find.text('بعد الإضافة: ٢٠'), findsOneWidget);
    });

    testWidgets('add mode rejects zero and non-numeric input', (tester) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(db, pharmacyId, productId, quantity: 15);
      await pumpProductsApp(tester, db, profileId: profileId);

      await openAdjustmentSheet(tester);
      final commit = find.widgetWithText(FilledButton, 'تحديث المخزون');

      // Empty input → disabled, no validation noise.
      expect(tester.widget<FilledButton>(commit).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'كثير');
      await tester.pump();
      expect(find.text('أدخل عددًا صحيحًا (مثال: 25)'), findsOneWidget);
      expect(tester.widget<FilledButton>(commit).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.pump();
      expect(tester.widget<FilledButton>(commit).onPressed, isNull);
      expect(await movements(), hasLength(1));
    });
  });

  group('StockAdjustmentSheet — correct mode', () {
    testWidgets('posts the signed delta toward the entered target', (
      tester,
    ) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(db, pharmacyId, productId, quantity: 45);
      await pumpProductsApp(tester, db, profileId: profileId);

      await openAdjustmentSheet(tester);
      await tester.tap(find.text('تصحيح الكمية'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '40');
      await tester.pump();
      expect(
        find.text('الفرق: ؜-٥ · الجديد: ٤٠'),
        findsOneWidget,
      );

      await tester.tap(find.text('تحديث المخزون'));
      await tester.pumpAndSettle();
      expect(find.text('المخزون: ٤٠'), findsOneWidget);

      final rows = await movements();
      expect(rows, hasLength(2));
      expect(rows.last.type, StockMovementType.adjustment);
      expect(rows.last.quantity, -5);
    });

    testWidgets('correcting an untracked product treats absent on-hand as 0',
        (tester) async {
      await seedProduct(db, pharmacyId);
      await pumpProductsApp(tester, db, profileId: profileId);

      await openAdjustmentSheet(tester);
      await tester.tap(find.text('تصحيح الكمية'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '3');
      await tester.pump();
      expect(find.text('الفرق: ٣ · الجديد: ٣'), findsOneWidget);

      await tester.tap(find.text('تحديث المخزون'));
      await tester.pumpAndSettle();
      expect(find.text('المخزون: ٣'), findsOneWidget);

      final rows = await movements();
      expect(rows, hasLength(1));
      expect(rows.single.type, StockMovementType.adjustment);
      expect(rows.single.quantity, 3);
    });

    testWidgets('zero delta shows the no-change state and disables commit', (
      tester,
    ) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(db, pharmacyId, productId, quantity: 45);
      await pumpProductsApp(tester, db, profileId: profileId);

      await openAdjustmentSheet(tester);
      await tester.tap(find.text('تصحيح الكمية'));
      await tester.pump();

      final commit = find.widgetWithText(FilledButton, 'تحديث المخزون');
      await tester.enterText(find.byType(TextField).first, '45');
      await tester.pump();

      expect(find.text('لا يوجد تغيير'), findsOneWidget);
      expect(tester.widget<FilledButton>(commit).onPressed, isNull);

      // A different target re-enables commit and the preview returns.
      await tester.enterText(find.byType(TextField).first, '50');
      await tester.pump();
      expect(find.text('لا يوجد تغيير'), findsNothing);
      expect(find.text('الفرق: ٥ · الجديد: ٥٠'), findsOneWidget);
      expect(tester.widget<FilledButton>(commit).onPressed, isNotNull);
      expect(await movements(), hasLength(1));
    });
  });
}
