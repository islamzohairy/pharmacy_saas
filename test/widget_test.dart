import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/l10n/generated/app_localizations.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';

import 'support/helpers.dart';

class FakeSecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  testWidgets('app boots to the onboarding route, RTL', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStoreProvider.overrideWithValue(FakeSecureStore())],
        child: PharmacyApp(
          router: buildRouter(initialLocation: AppRoutes.onboarding),
        ),
      ),
    );

    expect(find.text('مرحباً بك'), findsOneWidget);
    expect(find.text('اسم الصيدلية'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('other P0 routes render RTL with Arabic strings', (tester) async {
    final routes = <String, String>{
      '/products': 'المنتجات',
      '/sales': 'المبيعات',
      '/expenses': 'المصروفات',
      '/supplier-debt': 'ديون الموردين',
      '/customer-debt': 'ديون العملاء',
      '/dashboard': 'لوحة التحكم',
    };

    for (final entry in routes.entries) {
      // Products, sales and expenses are DB-backed — seed a tenant with an
      // active profile so their providers resolve; the rest render stubs.
      final needsDb = entry.key == '/products' ||
          entry.key == '/sales' ||
          entry.key == '/expenses';
      final db = needsDb ? await createMemoryDb() : null;
      addTearDown(() => db?.close());
      final store = FakeSecureStore();
      if (db != null) {
        final pharmacyId = await seedPharmacy(db);
        final profileId = await seedProfile(db, pharmacyId);
        await seedProduct(db, pharmacyId);
        await store.write('last_active_profile_id', '$profileId');
      }

      final router = buildRouter(initialLocation: entry.key);
      await tester.pumpWidget(
        ProviderScope(
          // A fresh element per route: the override list differs between
          // stub routes (1 override) and DB-backed routes (2).
          key: ValueKey(entry.key),
          overrides: [
            secureStoreProvider.overrideWithValue(store),
            if (db != null) appDatabaseProvider.overrideWithValue(db),
          ],
          child: PharmacyApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget, reason: entry.key);

      final directionality = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(directionality.textDirection, TextDirection.rtl);

      // The next iteration swaps this widget tree while the DB-backed
      // routes' drift-watch providers are still mounted — without
      // flushing their close timers the fake-async zone wedges (Plan 07
      // lesson; the products route now watches two drift streams, so the
      // single-stream margin no longer covers this loop).
      await unmountAndFlushDriftTimers(tester);
    }
  });

  test('ar is a supported locale', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('ar')));
    expect(
      GlobalMaterialLocalizations.delegate.isSupported(const Locale('ar')),
      isTrue,
    );
  });
}
