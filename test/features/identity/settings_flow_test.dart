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
/// profile and the settings screen as the initial route.
Future<ProviderContainer> pumpSettingsApp(
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
          PharmacyApp(router: buildRouter(initialLocation: AppRoutes.settings)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _taxField() =>
    find.widgetWithText(TextFormField, 'الرقم الضريبي');
Finder _legalNameField() =>
    find.widgetWithText(TextFormField, 'الاسم القانوني للنشاط');
Finder _saveButton() => find.text('حفظ');

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

  group('SettingsScreen', () {
    testWidgets('saves the compliance-prep fields and shows confirmation',
        (tester) async {
      await pumpSettingsApp(tester, db, profileId: profileId);

      await tester.enterText(_taxField(), '123-456-789');
      await tester.enterText(
        _legalNameField(),
        'صيدلية النور للمستلزمات الطبية',
      );
      await tester.ensureVisible(_saveButton());
      await tester.tap(_saveButton());
      await tester.pumpAndSettle();

      expect(find.text('تم حفظ الإعدادات'), findsOneWidget);

      final pharmacy = (await db.select(db.pharmacies).get()).single;
      expect(pharmacy.taxRegistrationNumber, '123-456-789');
      expect(
        pharmacy.legalBusinessName,
        'صيدلية النور للمستلزمات الطبية',
      );
    });

    testWidgets('empty fields save as null (clearing)', (tester) async {
      await seedPharmacySettings(db, pharmacyId);
      await pumpSettingsApp(tester, db, profileId: profileId);
      await tester.pumpAndSettle();

      // Seeded values are pre-filled into the form…
      expect(
        tester.widget<TextFormField>(_taxField()).controller!.text,
        'abc-123',
      );

      // …clearing them and saving stores null.
      await tester.enterText(_taxField(), '');
      await tester.ensureVisible(_saveButton());
      await tester.tap(_saveButton());
      await tester.pumpAndSettle();

      final pharmacy = (await db.select(db.pharmacies).get()).single;
      expect(pharmacy.taxRegistrationNumber, isNull);
    });

    testWidgets('auto-deduct toggle defaults ON and persists after save', (
      tester,
    ) async {
      await pumpSettingsApp(tester, db, profileId: profileId);

      // Default ON on a fresh pharmacy (PLANS/13 §5.4 + D27/D28).
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);

      // Toggle off and save.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);
      await tester.ensureVisible(_saveButton());
      await tester.tap(_saveButton());
      await tester.pumpAndSettle();
      expect(find.text('تم حفظ الإعدادات'), findsOneWidget);

      var pharmacy = (await db.select(db.pharmacies).get()).single;
      expect(pharmacy.autoDeductStock, isFalse);

      // "Restart" — a fresh pump over the same DB — stays OFF.
      await unmountAndFlushDriftTimers(tester);
      await pumpSettingsApp(tester, db, profileId: profileId);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);
      pharmacy = (await db.select(db.pharmacies).get()).single;
      expect(pharmacy.autoDeductStock, isFalse);
    });

    testWidgets('toggle off keeps compliance fields untouched', (tester) async {
      await seedPharmacySettings(db, pharmacyId);
      await pumpSettingsApp(tester, db, profileId: profileId);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.ensureVisible(_saveButton());
      await tester.tap(_saveButton());
      await tester.pumpAndSettle();

      final pharmacy = (await db.select(db.pharmacies).get()).single;
      expect(pharmacy.autoDeductStock, isFalse);
      expect(pharmacy.taxRegistrationNumber, 'abc-123');
    });
  });
}