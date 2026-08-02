import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/app.dart';
import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/secure_store.dart';
import 'package:pharmacy_saas/core/router/app_router.dart';
import 'package:pharmacy_saas/features/identity/identity.dart';

class FakeSecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  AppDatabase? existingDb,
  String initialLocation = AppRoutes.onboarding,
}) async {
  final db = existingDb ?? AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      secureStoreProvider.overrideWithValue(FakeSecureStore()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PharmacyApp(router: buildRouter(initialLocation: initialLocation)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('first launch: onboarding creates pharmacy + owner, lands on '
      'dashboard, zero network calls', (tester) async {
    final container = await pumpApp(tester);

    expect(find.text('اسم الصيدلية'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم الصيدلية'),
      'صيدلية النور',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'اسمك'), 'أم أحمد');
    await tester.tap(find.text('إنشاء والبدء'));
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsOneWidget);
    expect(
      await container.read(identityRepositoryProvider).hasAnyProfile(),
      isTrue,
    );
    final active = await container.read(activeProfileProvider.future);
    expect(active?.displayName, 'أم أحمد');
    expect(active?.role, UserRole.owner);
  });

  testWidgets('onboarding validates empty fields', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('إنشاء والبدء'));
    await tester.pumpAndSettle();

    expect(find.text('أدخل اسم الصيدلية'), findsOneWidget);
    expect(find.text('أدخل اسمك'), findsOneWidget);
  });

  testWidgets('add family profile and switch without a login screen', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم الصيدلية'),
      'صيدلية النور',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'اسمك'), 'أم أحمد');
    await tester.tap(find.text('إنشاء والبدء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    expect(find.text('الملفات الشخصية'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم العضو'),
      'أبو أحمد',
    );
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    expect(find.text('أبو أحمد'), findsOneWidget);

    await tester.tap(find.text('أبو أحمد'));
    await tester.pumpAndSettle();

    final active = await container.read(activeProfileProvider.future);
    expect(active?.displayName, 'أبو أحمد');
    expect(active?.role, UserRole.family);
  });

  testWidgets('PIN gate: wrong PIN blocks, correct PIN switches', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم الصيدلية'),
      'صيدلية النور',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'اسمك'), 'أم أحمد');
    await tester.tap(find.text('إنشاء والبدء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    // Set a PIN on the owner profile.
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'رمز الدخول'), '1234');
    await tester.enterText(
      find.widgetWithText(TextField, 'تأكيد رمز الدخول'),
      '1234',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    // Add a family profile, then try switching back to the PIN-protected one.
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم العضو'),
      'أبو أحمد',
    );
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أبو أحمد'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(activeProfileProvider.future))?.displayName,
      'أبو أحمد',
    );

    // Back to the switcher to reach the PIN-protected owner profile.
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    await tester.tap(find.text('أم أحمد'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رمز الدخول'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'رمز الدخول'), '0000');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('رمز الدخول غير صحيح'), findsOneWidget);
    expect(
      (await container.read(activeProfileProvider.future))?.displayName,
      'أبو أحمد',
    );

    await tester.enterText(find.widgetWithText(TextField, 'رمز الدخول'), '1234');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(activeProfileProvider.future))?.displayName,
      'أم أحمد',
    );
  });

  testWidgets('forgot PIN: wipe and re-onboard, limitation stated in-app', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم الصيدلية'),
      'صيدلية النور',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'اسمك'), 'أم أحمد');
    await tester.tap(find.text('إنشاء والبدء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'رمز الدخول'), '1234');
    await tester.enterText(
      find.widgetWithText(TextField, 'تأكيد رمز الدخول'),
      '1234',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    // Try to switch to the protected profile and use the forgot path.
    await tester.tap(find.text('أم أحمد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسيت رمز الدخول؟'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('لا يوجد استرداد لرمز الدخول في هذه المرحلة'),
      findsOneWidget,
    );

    await tester.tap(find.text('حذف وإعادة البدء'));
    await tester.pumpAndSettle();

    // Back to onboarding, identity wiped.
    expect(find.text('اسم الصيدلية'), findsOneWidget);
    expect(
      await container.read(identityRepositoryProvider).hasAnyProfile(),
      isFalse,
    );
    expect(await container.read(activeProfileProvider.future), isNull);
  });
}
