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
/// profile (so the providers resolve a pharmacyId) and the draws screen as
/// the initial route.
Future<ProviderContainer> pumpDrawsApp(
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
      child: PharmacyApp(router: buildRouter(initialLocation: AppRoutes.draws)),
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

  group('DrawsScreen', () {
    testWidgets('validates empty and non-positive amounts', (tester) async {
      await pumpDrawsApp(tester, db, profileId: profileId);

      await tester.tap(find.text('تسجيل السحب'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل السعر'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'مبلغ السحب'),
        '0',
      );
      await tester.tap(find.text('تسجيل السحب'));
      await tester.pumpAndSettle();
      expect(find.text('يجب أن يكون السعر أكبر من صفر'), findsOneWidget);
    });

    testWidgets(
      'records one cashDraw row, attributes it, and clears the form',
      (tester) async {
        await pumpDrawsApp(tester, db, profileId: profileId);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'مبلغ السحب'),
          '150.50',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'ملاحظة (اختياري)'),
          'مصروف البيت',
        );
        await tester.tap(find.text('تسجيل السحب'));
        await tester.pumpAndSettle();

        expect(find.text('تم تسجيل السحب'), findsOneWidget);
        final rows = await db.select(db.ledgerEntries).get();
        expect(rows, hasLength(1));
        expect(rows.single.type, LedgerEntryType.cashDraw);
        expect(rows.single.amountMinor, 15050);
        expect(rows.single.note, 'مصروف البيت');
        expect(rows.single.profileId, profileId);

        // The form is cleared so the next draw is a handful of taps away.
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'مبلغ السحب'),
              )
              .controller!
              .text,
          isEmpty,
        );
      },
    );

    testWidgets('accepts Arabic-Indic digits', (tester) async {
      await pumpDrawsApp(tester, db, profileId: profileId);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'مبلغ السحب'),
        '٢٥٫٥٠',
      );
      await tester.tap(find.text('تسجيل السحب'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.ledgerEntries).get();
      expect(rows.single.amountMinor, 2550);
    });
  });
}
