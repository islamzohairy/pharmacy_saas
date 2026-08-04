import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/data/tables/expense_category.dart';
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
/// profile (so the providers resolve a pharmacyId) and the expenses screen as
/// the initial route.
Future<ProviderContainer> pumpExpensesApp(
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
          PharmacyApp(router: buildRouter(initialLocation: AppRoutes.expenses)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _amountField() =>
    find.widgetWithText(TextFormField, 'مبلغ المصروف');
Finder _noteField() =>
    find.widgetWithText(TextFormField, 'ملاحظة (اختياري)');
Finder _recordButton() => find.text('تسجيل المصروف');

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

  group('ExpensesScreen', () {
    testWidgets('validates empty and non-positive amounts', (tester) async {
      await pumpExpensesApp(tester, db, profileId: profileId);

      await tester.tap(_recordButton());
      await tester.pumpAndSettle();
      expect(find.text('أدخل السعر'), findsOneWidget);

      await tester.enterText(_amountField(), '0');
      await tester.tap(_recordButton());
      await tester.pumpAndSettle();
      expect(find.text('يجب أن يكون السعر أكبر من صفر'), findsOneWidget);
    });

    testWidgets(
      'records one expense row with the default Owner Draw category, '
      'attributes it, and clears the form',
      (tester) async {
        await pumpExpensesApp(tester, db, profileId: profileId);

        await tester.enterText(_amountField(), '150.50');
        await tester.enterText(_noteField(), 'مصروف البيت');
        await tester.tap(_recordButton());
        await tester.pumpAndSettle();

        expect(find.text('تم تسجيل المصروف'), findsOneWidget);
        final rows = await db.select(db.ledgerEntries).get();
        expect(rows, hasLength(1));
        expect(rows.single.type, LedgerEntryType.expense);
        expect(rows.single.category, ExpenseCategory.ownerDraw);
        expect(rows.single.amountMinor, 15050);
        expect(rows.single.note, 'مصروف البيت');
        expect(rows.single.profileId, profileId);

        // The form is cleared so the next expense is a handful of taps away.
        expect(
          tester.widget<TextFormField>(_amountField()).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'records an expense with a non-default category and shows it in the '
      'history list',
      (tester) async {
        await pumpExpensesApp(tester, db, profileId: profileId);

        await tester.tap(find.byType(DropdownButtonFormField<ExpenseCategory>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إيجار').last);
        await tester.pumpAndSettle();

        await tester.enterText(_amountField(), '2000');
        await tester.tap(_recordButton());
        await tester.pumpAndSettle();

        final rows = await db.select(db.ledgerEntries).get();
        expect(rows, hasLength(1));
        expect(rows.single.type, LedgerEntryType.expense);
        expect(rows.single.category, ExpenseCategory.rent);
        expect(rows.single.amountMinor, 200000);

        // The history list shows the category, the formatted amount and the
        // header for the default (Arabic) locale. 'إيجار' appears twice: the
        // dropdown shows the selected value, the history list shows the row.
        expect(find.text('آخر المصروفات'), findsOneWidget);
        expect(find.text('إيجار'), findsNWidgets(2));
        expect(find.text('٢٬٠٠٠٫٠٠ ج.م'), findsOneWidget);
      },
    );

    testWidgets('accepts Arabic-Indic digits', (tester) async {
      await pumpExpensesApp(tester, db, profileId: profileId);

      await tester.enterText(_amountField(), '٢٥٫٥٠');
      await tester.tap(_recordButton());
      await tester.pumpAndSettle();

      final rows = await db.select(db.ledgerEntries).get();
      expect(rows.single.amountMinor, 2550);
    });
  });
}