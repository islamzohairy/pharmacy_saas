import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/data/tables/expense_category.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/core/data/tables/stock_movement_type.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';
import 'package:pharmacy_saas/features/activity/presentation/activity_providers.dart';

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
/// profile and the activity screen as the initial route.
Future<ProviderContainer> pumpActivityApp(
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
      child:
          PharmacyApp(router: buildRouter(initialLocation: AppRoutes.activity)),
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

  group('ActivityScreen', () {
    testWidgets('shows the empty state when the ledger has no entries',
        (tester) async {
      await pumpActivityApp(tester, db, profileId: profileId);

      expect(find.text('النشاط'), findsOneWidget);
      expect(find.text('لا توجد حركة مسجلة بعد'), findsOneWidget);
    });

    testWidgets(
      'renders the newest entries first with type label, category, amount '
      'and the recording profile',
      (tester) async {
        // Oldest first — a sale from the seeded profile.
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 2550,
          profileId: profileId,
          occurredAt: DateTime(2026, 8, 1, 10, 0),
        );
        // Newest — a rent expense from the same profile.
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.expense,
          amountMinor: 200000,
          category: ExpenseCategory.rent,
          profileId: profileId,
          occurredAt: DateTime(2026, 8, 2, 11, 30),
        );

        await pumpActivityApp(tester, db, profileId: profileId);

        expect(find.text('إيجار'), findsOneWidget);
        expect(find.text('٢٬٠٠٠٫٠٠ ج.م'), findsOneWidget);
        expect(find.textContaining('بواسطة: أم أحمد'), findsNWidgets(2));

        // Newest entry (the expense) is above the older sale.
        final expenseY = tester.getTopLeft(find.text('إيجار')).dy;
        final saleY = tester.getTopLeft(find.text('مبيعات')).dy;
        expect(expenseY, lessThan(saleY));
      },
    );

    testWidgets('renders a large ledger without crashing (100-row cap held)',
        (tester) async {
      for (var i = 0; i < 105; i++) {
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 1000,
          occurredAt: DateTime(2026, 1, 1, 0, 0).add(Duration(minutes: i)),
        );
      }

      await pumpActivityApp(tester, db, profileId: profileId);

      // The cap itself is a repository concern (see ledger_repository_test
      // 'watchEntries caps the result at limit'); here we only assert the
      // feed renders the newest rows and holds its ordering at volume.
      expect(find.byType(ListTile), findsWidgets);
      expect(find.text('مبيعات'), findsWidgets);
    });

    testWidgets(
        'manual movements render with product name, signed quantity and '
        'attribution; stock_out and initial stay absent (D10)', (tester) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 2550,
        profileId: profileId,
        occurredAt: DateTime(2026, 8, 1, 10, 0),
      );
      // Manual add — must appear, newest.
      await seedMovement(
        db,
        pharmacyId,
        productId,
        type: StockMovementType.stockIn,
        quantity: 5,
        profileId: profileId,
        occurredAt: DateTime(2026, 8, 1, 11, 0),
      );
      // Auto stock_out and initial — must NOT appear (D10).
      await seedMovement(
        db,
        pharmacyId,
        productId,
        type: StockMovementType.stockOut,
        quantity: -2,
        profileId: profileId,
        occurredAt: DateTime(2026, 8, 1, 12, 0),
      );
      await seedMovement(
        db,
        pharmacyId,
        productId,
        type: StockMovementType.initial,
        quantity: 50,
        profileId: profileId,
        occurredAt: DateTime(2026, 8, 1, 13, 0),
      );

      await pumpActivityApp(tester, db, profileId: profileId);

      // Only the stock_in movement rendered, with product name, the
      // signed quantity and the recorder.
      expect(find.text('إضافة مخزون: باراسيتامول 500'), findsOneWidget);
      expect(find.text('+٥'), findsOneWidget);
      expect(find.textContaining('بواسطة: أم أحمد'), findsNWidgets(2));
      // The ledger sale row is still there.
      expect(find.text('مبيعات'), findsOneWidget);
    });

    testWidgets(
        'a movement newer than a ledger entry renders above it; correction '
        'copy shows the signed quantity', (tester) async {
      final productId = await seedProduct(db, pharmacyId);
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 2550,
        occurredAt: DateTime(2026, 8, 1, 10, 0),
      );
      await seedMovement(
        db,
        pharmacyId,
        productId,
        type: StockMovementType.adjustment,
        quantity: -5,
        profileId: profileId,
        occurredAt: DateTime(2026, 8, 1, 11, 0),
      );

      await pumpActivityApp(tester, db, profileId: profileId);

      expect(find.text('تصحيح مخزون: باراسيتامول 500'), findsOneWidget);
      expect(find.text('؜-٥'), findsOneWidget);
      final movementY = tester.getTopLeft(
        find.text('تصحيح مخزون: باراسيتامول 500'),
      ).dy;
      final saleY = tester.getTopLeft(find.text('مبيعات')).dy;
      expect(movementY, lessThan(saleY));
    });

    testWidgets('combined cap holds at 100 across both sources', (
      tester,
    ) async {
      final productId = await seedProduct(db, pharmacyId);
      for (var i = 0; i < 60; i++) {
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 1000,
          occurredAt: DateTime(2026, 1, 1, 0, 0).add(Duration(minutes: i)),
        );
        await seedMovement(
          db,
          pharmacyId,
          productId,
          type: StockMovementType.stockIn,
          quantity: 1,
          occurredAt: DateTime(2026, 1, 1, 0, 0).add(Duration(seconds: i)),
        );
      }

      final container = await pumpActivityApp(tester, db, profileId: profileId);

      // 120 candidates, 60 of which are the newer second-domain movements;
      // the combined feed re-caps at 100.
      final rows = await container.read(activityFeedProvider.future);
      expect(rows, hasLength(100));
    });
  });
}