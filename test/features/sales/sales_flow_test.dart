import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';
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

/// Pumps the full app on a memory DB with one seeded pharmacy, an active
/// profile and one seeded product.
Future<ProviderContainer> pumpSalesApp(
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
  });
}
