import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/data/tables/stock_movement_type.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';
import 'package:pharmacy_saas/features/products/presentation/products_providers.dart';

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
/// profile (so the products providers resolve a pharmacyId) and the given
/// products.
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

  group('ProductsScreen', () {
    testWidgets('shows the empty state with an add FAB', (tester) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      expect(find.text('لا توجد منتجات بعد'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('lists active products with formatted sell price', (
      tester,
    ) async {
      await seedProduct(db, pharmacyId);
      await pumpProductsApp(tester, db, profileId: profileId);

      expect(find.text('باراسيتامول 500'), findsOneWidget);
      expect(find.text('٢٥٫٥٠ ج.م'), findsOneWidget);
    });

    testWidgets(
        'shows live on-hand per row, "—" when a product is not tracked',
        (tester) async {
      await seedProduct(db, pharmacyId, name: 'بانادول');
      final stocked = await seedProduct(db, pharmacyId, name: 'بروفين');
      await seedMovement(db, pharmacyId, stocked, quantity: 15);
      await pumpProductsApp(tester, db, profileId: profileId);

      // Stocked product shows its aggregate; the movement-less product
      // is not tracked and shows the neutral dash — never a false zero
      // (staff-review finding, DECISIONS.md 2026-08-13).
      expect(find.text('المخزون: ١٥'), findsOneWidget);
      expect(find.text('المخزون: —'), findsOneWidget);
      expect(find.text('المخزون: ٠'), findsNothing);
      expect(find.text('بانادول'), findsOneWidget);
      expect(find.text('بروفين'), findsOneWidget);
    });

    testWidgets('negative on-hand renders in the distinct error color (D3)',
        (tester) async {
      final product = await seedProduct(db, pharmacyId, name: 'بروفين');
      await seedMovement(db, pharmacyId, product, quantity: 5);
      await seedMovement(
        db,
        pharmacyId,
        product,
        type: StockMovementType.stockOut,
        quantity: -9,
      );
      await pumpProductsApp(tester, db, profileId: profileId);

      final onHandText = find.text('المخزون: ؜-٤');
      expect(onHandText, findsOneWidget);
      final textWidget = tester.widget<Text>(onHandText);
      expect(textWidget.style?.color, isNotNull);
      // Distinct visual state = the theme error color (never clamped,
      // never a warning dialog — the signal belongs to Plan 14).
      final context = tester.element(onHandText);
      expect(
        textWidget.style?.color,
        Theme.of(context).colorScheme.error,
      );
    });

    testWidgets('on-hand updates live when a movement is appended', (
      tester,
    ) async {
      final product = await seedProduct(db, pharmacyId, name: 'بروفين');
      await seedMovement(db, pharmacyId, product, quantity: 3);
      await pumpProductsApp(tester, db, profileId: profileId);
      expect(find.text('المخزون: ٣'), findsOneWidget);

      await seedMovement(db, pharmacyId, product, quantity: 7);
      await tester.pumpAndSettle();

      expect(find.text('المخزون: ١٠'), findsOneWidget);
      expect(find.text('المخزون: ٣'), findsNothing);
    });

    testWidgets('provider join: null on-hand for untracked, value for tracked',
        (tester) async {
      // Untracked product (no movements) joins as null — never a false
      // zero — while the tracked product carries its live aggregate
      // (staff-review finding, DECISIONS.md 2026-08-13).
      await seedProduct(db, pharmacyId, name: 'بانادول');
      final stocked = await seedProduct(db, pharmacyId, name: 'بروفين');
      await seedMovement(db, pharmacyId, stocked, quantity: 15);
      final container = await pumpProductsApp(
        tester,
        db,
        profileId: profileId,
      );

      final joined = await container
          .read(productsWithOnHandProvider.future);
      expect(joined.length, 2);
      final byName = {
        for (final (product, onHand) in joined) product.name: onHand,
      };
      expect(byName['بانادول'], isNull);
      expect(byName['بروفين'], 15);
    });

    testWidgets('creates a product through the form and returns to the list', (
      tester,
    ) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('إضافة منتج'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المنتج'),
        'بانادول',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر الشراء'),
        '20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر البيع'),
        '25.00',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('بانادول'), findsOneWidget);
      expect(find.text('٢٥٫٠٠ ج.م'), findsOneWidget);
    });

    testWidgets('validates empty and non-positive prices', (tester) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل اسم المنتج'), findsOneWidget);
      expect(find.text('أدخل السعر'), findsNWidgets(2));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر البيع'),
        '0',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('يجب أن يكون السعر أكبر من صفر'), findsOneWidget);
    });

    testWidgets('deactivates a product after confirmation', (tester) async {
      await seedProduct(db, pharmacyId, name: 'باراسيتامول 500');
      await seedProduct(db, pharmacyId, name: 'بروفين', costMinor: 3000);
      await pumpProductsApp(tester, db, profileId: profileId);

      expect(find.text('باراسيتامول 500'), findsOneWidget);
      expect(find.text('بروفين'), findsOneWidget);

      await tester.tap(find.byTooltip('تعطيل المنتج').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('«باراسيتامول 500»'), findsOneWidget);

      await tester.tap(find.text('تعطيل'));
      await tester.pumpAndSettle();

      expect(find.text('باراسيتامول 500'), findsNothing);
      expect(find.text('بروفين'), findsOneWidget);
    });

    testWidgets('edit opens the form pre-filled', (tester) async {
      await seedProduct(db, pharmacyId);
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byTooltip('تعديل منتج'));
      await tester.pumpAndSettle();

      expect(find.text('تعديل منتج'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'سعر الشراء'),
            )
            .controller!
            .text,
        '20.00',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'سعر البيع'),
            )
            .controller!
            .text,
        '25.50',
      );
    });
  });

  group('ProductForm initial stock', () {
    testWidgets('omitting the field creates the product with no movements', (
      tester,
    ) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المنتج'),
        'بانادول',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر الشراء'),
        '20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر البيع'),
        '25.00',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('بانادول'), findsOneWidget);
      expect(await db.select(db.stockMovements).get(), isEmpty);
    });

    testWidgets('a positive value posts exactly one initial movement',
        (tester) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المنتج'),
        'بانادول',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر الشراء'),
        '20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر البيع'),
        '25.00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المخزون الابتدائي'),
        '50',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final product = await (db.select(db.products)
            ..where((t) => t.name.equals('بانادول')))
          .getSingle();
      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.productId, product.id);
      expect(movements.single.type, StockMovementType.initial);
      expect(movements.single.quantity, 50);
      // Attributed to the active profile (plan-04 precedent).
      expect(movements.single.profileId, profileId);
    });

    testWidgets('Arabic-Indic digits are accepted via the shared path', (
      tester,
    ) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المنتج'),
        'بانادول',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر الشراء'),
        '٢٠',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر البيع'),
        '٢٥',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المخزون الابتدائي'),
        '٥٠',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.quantity, 50);
    });

    testWidgets('a zero value posts no movement (on-hand defaults to 0)', (
      tester,
    ) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المنتج'),
        'بانادول',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر الشراء'),
        '20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر البيع'),
        '25.00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المخزون الابتدائي'),
        '0',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(await db.select(db.stockMovements).get(), isEmpty);
    });

    testWidgets('rejects negative and non-numeric values', (tester) async {
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextFormField, 'المخزون الابتدائي');

      await tester.enterText(field, '-5');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل عددًا صحيحًا (مثال: 25)'), findsOneWidget);

      await tester.enterText(field, 'كثير');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل عددًا صحيحًا (مثال: 25)'), findsOneWidget);

      // Still on the form — nothing was saved.
      expect(find.text('إضافة منتج'), findsOneWidget);
      expect(await db.select(db.stockMovements).get(), isEmpty);
      expect(await db.select(db.products).get(), isEmpty);
    });

    testWidgets('edit shows no initial-stock field and posts no movement', (
      tester,
    ) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedMovement(db, pharmacyId, productId);
      await pumpProductsApp(tester, db, profileId: profileId);

      await tester.tap(find.byTooltip('تعديل منتج'));
      await tester.pumpAndSettle();

      expect(find.text('تعديل منتج'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'المخزون الابتدائي'),
        findsNothing,
      );

      // Save an edit without touching stock — history is unchanged.
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.quantity, 10);
    });
  });
}
