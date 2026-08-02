import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/l10n/generated/app_localizations.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';

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

  testWidgets('other P0 routes render RTL with Arabic strings', (
    tester,
  ) async {
    final routes = <String, String>{
      '/products': 'المنتجات',
      '/sales': 'المبيعات',
      '/draws': 'السحوبات',
      '/supplier-debt': 'ديون الموردين',
      '/customer-debt': 'ديون العملاء',
      '/dashboard': 'لوحة التحكم',
    };

    for (final entry in routes.entries) {
      final router = buildRouter(initialLocation: entry.key);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(FakeSecureStore()),
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
