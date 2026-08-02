import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';

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
}
