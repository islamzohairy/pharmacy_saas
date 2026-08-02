import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/l10n/generated/app_localizations.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';

void main() {
  testWidgets('app boots to the onboarding route, RTL', (tester) async {
    await tester.pumpWidget(const PharmacyApp());

    expect(find.text('مرحباً بك'), findsOneWidget);
    expect(find.text('هذه الشاشة قيد الإنشاء'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('all seven P0 routes render RTL with Arabic strings', (
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
      appRouter.go(entry.key);
      await tester.pumpWidget(const PharmacyApp());
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
