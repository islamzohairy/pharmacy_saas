import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
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
/// profile (so the providers resolve a pharmacyId) and the supplier debt
/// screen as the initial route.
Future<ProviderContainer> pumpSuppliersApp(
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
        router: buildRouter(initialLocation: AppRoutes.supplierDebt),
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

  group('SupplierDebtScreen', () {
    testWidgets('shows the empty state with an add FAB', (tester) async {
      await pumpSuppliersApp(tester, db, profileId: profileId);

      expect(find.text('لا يوجد موردون بعد'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('creates a supplier and shows a zero balance', (tester) async {
      await pumpSuppliersApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'اسم المورد'),
        'شركة النور',
      );
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      expect(find.text('شركة النور'), findsOneWidget);
      expect(find.text('٠٫٠٠ ج.م'), findsOneWidget);
    });

    testWidgets(
      'records a supplier debt as one ledger row and updates the balance',
      (tester) async {
        final supplierId = await seedSupplier(
          db,
          pharmacyId,
          name: 'شركة النور',
        );
        await pumpSuppliersApp(tester, db, profileId: profileId);

        await tester.tap(find.byTooltip('تسجيل دين'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المبلغ'),
          '25.50',
        );
        await tester.tap(find.text('حفظ'));
        await tester.pumpAndSettle();

        expect(find.text('تم تسجيل الدين'), findsOneWidget);
        expect(find.text('٢٥٫٥٠ ج.م'), findsOneWidget);

        final rows = await db.select(db.ledgerEntries).get();
        expect(rows, hasLength(1));
        expect(rows.single.type, LedgerEntryType.supplierDebt);
        expect(rows.single.supplierId, supplierId);
        expect(rows.single.amountMinor, 2550);
      },
    );

    testWidgets(
      'a repayment reduces the balance; overpayment renders as credit',
      (tester) async {
        final supplierId = await seedSupplier(
          db,
          pharmacyId,
          name: 'شركة النور',
        );
        await seedSupplierEntry(
          db,
          pharmacyId,
          supplierId,
          type: LedgerEntryType.supplierDebt,
          amountMinor: 2550,
        );
        await pumpSuppliersApp(tester, db, profileId: profileId);

        expect(find.text('٢٥٫٥٠ ج.م'), findsOneWidget);

        await tester.tap(find.byTooltip('تسجيل سداد'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المبلغ'),
          '30',
        );
        await tester.tap(find.text('حفظ'));
        await tester.pumpAndSettle();

        expect(find.text('تم تسجيل السداد'), findsOneWidget);
        // 25.50 debt − 30.00 repayment = −4.50 → credit, never clamped.
        expect(find.text('رصيد دائن ٤٫٥٠ ج.م'), findsOneWidget);
      },
    );

    testWidgets('sorts non-zero balances first, largest first', (tester) async {
      await seedSupplier(db, pharmacyId, name: 'أحمد');
      final supplierB = await seedSupplier(db, pharmacyId, name: 'بكر');
      await seedSupplierEntry(
        db,
        pharmacyId,
        supplierB,
        type: LedgerEntryType.supplierDebt,
        amountMinor: 5000,
      );
      await pumpSuppliersApp(tester, db, profileId: profileId);

      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(titles, ['بكر', 'أحمد']);
    });

    testWidgets('validates the debt amount in the dialog', (tester) async {
      await seedSupplier(db, pharmacyId, name: 'شركة النور');
      await pumpSuppliersApp(tester, db, profileId: profileId);

      await tester.tap(find.byTooltip('تسجيل دين'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل السعر'), findsOneWidget);
    });
  });
}
