import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';
import 'package:pharmacy_saas/features/dashboard/domain/dashboard_range.dart';

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

/// Waits a real 1.1s so an away-write's `occurred_at` (stored by drift at
/// unix-second granularity) falls strictly after the dashboard provider's
/// frozen `to` boundary. Without the gap, a write landing in the same
/// wall-clock second as the provider's creation slips inside the stale
/// window and the pre-fix bug stops reproducing deterministically.
Future<void> waitPastProviderSecond(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1100)),
  );
}

/// Pumps the full app on a memory DB with one seeded pharmacy and an
/// active profile, starting on the dashboard — the plan 07 default route.
Future<ProviderContainer> pumpDashboardApp(
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
        router: buildRouter(initialLocation: AppRoutes.dashboard),
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

  group('DashboardScreen', () {
    testWidgets(
      'shows the onboarding-style empty state on a first-day ledger',
      (tester) async {
        await pumpDashboardApp(tester, db, profileId: profileId);

        expect(find.text('ابدأ بتسجيل أول عملية بيع'), findsOneWidget);
        expect(find.text('تسجيل عملية بيع'), findsOneWidget);
        expect(find.byType(SegmentedButton<DashboardRange>), findsNothing);
      },
    );

    testWidgets('today (the default range) shows only today\'s profit plus the '
        'all-time debt totals', (tester) async {
      final productId = await seedProduct(
        db,
        pharmacyId,
        costMinor: 2000,
        sellMinor: 2550,
      );
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 5100, // 2 × 2550
        productId: productId,
      );
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.expense,
        amountMinor: 1000,
      );
      // Outside today: must not appear in the profit figures.
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 2550,
        productId: productId,
        occurredAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      // All-time: debt totals ignore the range.
      final supplierId = await seedSupplier(db, pharmacyId);
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.supplierDebt,
        amountMinor: 2500,
        supplierId: supplierId,
        occurredAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      await pumpDashboardApp(tester, db, profileId: profileId);

        // Sales 51.00, cost 20.00 (one sale entry → cost resolved once,
        // plan 04 semantics), draws 10.00, net 21.00.
        expect(find.text('٥١٫٠٠ ج.م'), findsOneWidget);
        expect(find.text('٢٠٫٠٠ ج.م'), findsOneWidget);
        expect(find.text('١٠٫٠٠ ج.م'), findsOneWidget);
        expect(find.text('٢١٫٠٠ ج.م'), findsOneWidget);
      // The 2-day-old sale is out of range; the 10-day-old debt is not.
      expect(find.text('٢٥٫٥٠ ج.م'), findsNothing);
      expect(find.text('٢٥٫٠٠ ج.م'), findsOneWidget);

      // Today is the default selection.
      final selector = tester.widget<SegmentedButton<DashboardRange>>(
        find.byType(SegmentedButton<DashboardRange>),
      );
      expect(selector.selected, {DashboardRange.today});

      // Permanent chrome: profile entry and backup status.
      expect(find.byTooltip('الملفات الشخصية'), findsOneWidget);
      expect(find.text('لم تتم المزامنة بعد'), findsOneWidget);
    });

    testWidgets('week range reaches back to the last Saturday only', (
      tester,
    ) async {
      final now = DateTime.now();
      final (weekStart, _) = rangeOf(DashboardRange.week, now);
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 3300,
        occurredAt: weekStart,
      );
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.expense,
        amountMinor: 1000,
        occurredAt: weekStart,
      );
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 4400,
        occurredAt: weekStart.subtract(const Duration(seconds: 1)),
      );
      await pumpDashboardApp(tester, db, profileId: profileId);

      await tester.tap(find.text('هذا الأسبوع'));
      await tester.pumpAndSettle();

      // Sales 33.00, net 23.00 (draw 10.00) — the two figures differ, so
      // findsOneWidget proves the range (the day-old sale is out).
      expect(find.text('٣٣٫٠٠ ج.م'), findsOneWidget);
      expect(find.text('٢٣٫٠٠ ج.م'), findsOneWidget);
      expect(find.text('٤٤٫٠٠ ج.م'), findsNothing);
    });

    testWidgets('month range covers the whole current month', (tester) async {
      final now = DateTime.now();
      final (monthStart, _) = rangeOf(DashboardRange.month, now);
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 5500,
        occurredAt: monthStart,
      );
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.expense,
        amountMinor: 1000,
        occurredAt: monthStart,
      );
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 6600,
        occurredAt: monthStart.subtract(const Duration(seconds: 1)),
      );
      await pumpDashboardApp(tester, db, profileId: profileId);

      await tester.tap(find.text('هذا الشهر'));
      await tester.pumpAndSettle();

      // Sales 55.00, net 45.00 — the two figures differ, so findsOneWidget
      // proves the range (the previous-month sale is out).
      expect(find.text('٥٥٫٠٠ ج.م'), findsOneWidget);
      expect(find.text('٤٥٫٠٠ ج.م'), findsOneWidget);
      expect(find.text('٦٦٫٠٠ ج.م'), findsNothing);
    });

    testWidgets('deactivated products still resolve cost for historical sales', (
      tester,
    ) async {
      final productId = await seedProduct(
        db,
        pharmacyId,
        costMinor: 2000,
        sellMinor: 2550,
      );
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 5100,
        productId: productId,
      );
        // Retire the product after the sale happened.
        await (db.update(db.products)..where((t) => t.id.equals(productId)))
            .write(const ProductsCompanion(isActive: Value(false)));
        await pumpDashboardApp(tester, db, profileId: profileId);

        // Cost still resolves from the retained row (watchAll, not
        // watchActive): 20.00 for the single sale entry.
        expect(find.text('٢٠٫٠٠ ج.م'), findsOneWidget);
    });

    testWidgets(
      'a range with only debt entries renders zeros, not the empty state',
      (tester) async {
        final supplierId = await seedSupplier(db, pharmacyId);
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.supplierDebt,
          amountMinor: 2500,
          supplierId: supplierId,
          occurredAt: DateTime.now().subtract(const Duration(days: 2)),
        );
        await pumpDashboardApp(tester, db, profileId: profileId);

        expect(find.text('ابدأ بتسجيل أول عملية بيع'), findsNothing);
        expect(find.text('٢٥٫٠٠ ج.م'), findsOneWidget);
      },
    );

    testWidgets('nav hub opens the sales screen from the sales tile', (
      tester,
    ) async {
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 1000,
      );
      await pumpDashboardApp(tester, db, profileId: profileId);

      await tester.tap(find.widgetWithText(ListTile, 'المبيعات'));
      await tester.pumpAndSettle();

      // Sales empty state (no products yet) — unambiguous marker of the
      // sales screen after navigation.
      expect(find.text('الذهاب إلى المنتجات'), findsOneWidget);
      // Flush drift's close timers before teardown (see
      // unmountAndFlushDriftTimers). Navigation alone doesn't dispose the
      // dashboard providers — the hub is a push, so the dashboard stays
      // mounted beneath it (DECISIONS.md 2026-08-03); the flush is for the
      // end-of-test unmount.
      await unmountAndFlushDriftTimers(tester);
    });

    testWidgets('nav hub opens the products screen from the products tile', (
      tester,
    ) async {
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 1000,
      );
      await pumpDashboardApp(tester, db, profileId: profileId);

      // The nav hub sits below the cards in a ListView; the products tile
      // can be outside the 800x600 test viewport, so scroll it in first.
      await tester.ensureVisible(find.widgetWithText(ListTile, 'المنتجات'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ListTile, 'المنتجات'));
      await tester.pumpAndSettle();

      // Products empty state CTA — unambiguous marker of the products screen.
      expect(find.text('إضافة منتج'), findsOneWidget);
      // Flush drift's close timers (see the sales test).
      await unmountAndFlushDriftTimers(tester);
    });

    testWidgets('back from a hub screen returns to the dashboard', (
      tester,
    ) async {
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 1000,
      );
      await pumpDashboardApp(tester, db, profileId: profileId);

      await tester.tap(find.widgetWithText(ListTile, 'المبيعات'));
      await tester.pumpAndSettle();
      expect(find.text('الذهاب إلى المنتجات'), findsOneWidget);

      // Hub navigation is a push (DECISIONS.md 2026-08-03), so the system
      // back gesture returns to the dashboard instead of exiting the app.
      // `tester.pageBack()` only matches the English 'Back' tooltip; the
      // RTL app localizes it, so tap the BackButton type directly.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('صافي الربح'), findsOneWidget);
      await unmountAndFlushDriftTimers(tester);
    });

    testWidgets('back from the sales products CTA returns to sales', (
      tester,
    ) async {
      await seedLedgerEntry(
        db,
        pharmacyId,
        type: LedgerEntryType.sale,
        amountMinor: 1000,
      );
      await pumpDashboardApp(tester, db, profileId: profileId);

      await tester.tap(find.widgetWithText(ListTile, 'المبيعات'));
      await tester.pumpAndSettle();
      // Sales empty state → its CTA pushes products (was goNamed).
      await tester.tap(find.text('الذهاب إلى المنتجات'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة منتج'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Back lands on the sales screen it was pushed from, not on the
      // dashboard — the CTA route is pushed on top of sales.
      expect(find.text('الذهاب إلى المنتجات'), findsOneWidget);
      await unmountAndFlushDriftTimers(tester);
    });

    testWidgets(
      'a sale recorded on the sales screen shows after returning to the '
      'dashboard',
      (tester) async {
        final productId = await seedProduct(
          db,
          pharmacyId,
          costMinor: 2000,
          sellMinor: 2550,
        );
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 2550,
          productId: productId,
        );
        await pumpDashboardApp(tester, db, profileId: profileId);
        expect(find.text('٢٥٫٥٠ ج.م'), findsOneWidget);

        await tester.tap(find.widgetWithText(ListTile, 'المبيعات'));
        await tester.pumpAndSettle();
        // Sales screen with the seeded product listed — unambiguous against
        // the offstage dashboard beneath the push.
        expect(find.text('باراسيتامول 500'), findsOneWidget);

        // Write AFTER the dashboard provider was created: the provider's
        // captured `to` boundary (pre-fix) excludes this row.
        await waitPastProviderSecond(tester);
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 5100,
          productId: productId,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // 25.50 + 51.00 — the away-write must be live on return.
        expect(find.text('٧٦٫٥٠ ج.م'), findsOneWidget);
        await unmountAndFlushDriftTimers(tester);
      },
    );

    testWidgets(
      'a draw recorded on the expenses screen shows after returning to the '
      'dashboard',
      (tester) async {
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 2550,
        );
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.expense,
          amountMinor: 1000,
        );
        await pumpDashboardApp(tester, db, profileId: profileId);
        // Sales 25.50 vs expenses 10.00 — distinct figures.
        expect(find.text('٢٥٫٥٠ ج.م'), findsOneWidget);
        expect(find.text('١٠٫٠٠ ج.م'), findsOneWidget);

        await tester.ensureVisible(
          find.widgetWithText(ListTile, 'المصروفات'),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(ListTile, 'المصروفات'));
        await tester.pumpAndSettle();
        // Expenses form marker — unambiguous against the dashboard beneath.
        expect(find.text('تسجيل المصروف'), findsOneWidget);

        await waitPastProviderSecond(tester);
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.expense,
          amountMinor: 5000,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // The dashboard restored its pre-navigation scroll position (scrolled
        // down to the expenses tile), so the profit card with the live figure
        // is off-screen and not built by the lazy list — drag back toward the
        // top before asserting the away-write is live on return.
        await tester.drag(find.byType(ListView).first, const Offset(0, 800));
        await tester.pumpAndSettle();
        expect(find.text('٦٠٫٠٠ ج.م'), findsOneWidget);
        await unmountAndFlushDriftTimers(tester);
      },
    );

    testWidgets(
      'a supplier debt recorded on the supplier screen shows after '
      'returning to the dashboard',
      (tester) async {
        final supplierId = await seedSupplier(db, pharmacyId);
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.supplierDebt,
          amountMinor: 2500,
          supplierId: supplierId,
        );
        await pumpDashboardApp(tester, db, profileId: profileId);
        expect(find.text('٢٥٫٠٠ ج.م'), findsOneWidget);

        await tester.ensureVisible(
          find.widgetWithText(ListTile, 'ديون الموردين'),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(ListTile, 'ديون الموردين'));
        await tester.pumpAndSettle();
        // The seeded supplier's tile — never rendered on the dashboard.
        expect(find.text('مورد الأدوية'), findsOneWidget);

        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.supplierDebt,
          amountMinor: 5000,
          supplierId: supplierId,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // 25.00 + 50.00 — the away-write must be live on return.
        expect(find.text('٧٥٫٠٠ ج.م'), findsOneWidget);
        await unmountAndFlushDriftTimers(tester);
      },
    );

    testWidgets(
      'a sale written while away lands inside the week range without '
      'moving the week boundary',
      (tester) async {
        final now = DateTime.now();
        final (weekStart, _) = rangeOf(DashboardRange.week, now);
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 3300,
          occurredAt: weekStart,
        );
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.expense,
          amountMinor: 3000,
          occurredAt: weekStart,
        );
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 4400,
          occurredAt: weekStart.subtract(const Duration(seconds: 1)),
        );
        await pumpDashboardApp(tester, db, profileId: profileId);

        await tester.tap(find.text('هذا الأسبوع'));
        await tester.pumpAndSettle();
        // Sales 33.00, draws 30.00 — distinct figures so the range is provable.
        expect(find.text('٣٣٫٠٠ ج.م'), findsOneWidget);
        expect(find.text('٣٠٫٠٠ ج.م'), findsOneWidget);
        expect(find.text('٤٤٫٠٠ ج.م'), findsNothing);

        await tester.tap(find.widgetWithText(ListTile, 'المبيعات'));
        await tester.pumpAndSettle();
        // The provider's `to` was captured at the range switch above — wait
        // past that second so the away-write is deterministically excluded.
        await waitPastProviderSecond(tester);
        await seedLedgerEntry(
          db,
          pharmacyId,
          type: LedgerEntryType.sale,
          amountMinor: 2000,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // 33.00 + 20.00 = 53.00 — the away-write is in-window; the
        // pre-week-start sale (44.00) must still be filtered out.
        expect(find.text('٥٣٫٠٠ ج.م'), findsOneWidget);
        expect(find.text('٤٤٫٠٠ ج.م'), findsNothing);
        await unmountAndFlushDriftTimers(tester);
      },
    );
  });
}
