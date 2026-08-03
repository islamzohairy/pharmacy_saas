import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/error_log_repository.dart';
import 'package:pharmacy_saas/core/l10n/generated/app_localizations.dart';
import 'package:pharmacy_saas/core/widgets/error_log_indicator.dart';

import '../../support/helpers.dart';

void main() {
  late AppDatabase db;
  late ErrorLogRepository repository;

  Future<ProviderContainer> pumpIndicator(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ErrorLogIndicator()),
        ),
      ),
    );
    return container;
  }

  setUp(() async {
    db = await createMemoryDb();
    repository = ErrorLogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('hidden while there are no unreported errors', (tester) async {
    await pumpIndicator(tester);

    expect(find.textContaining('أخطاء غير مُبلَّغ عنها'), findsNothing);
    await unmountAndFlushDriftTimers(tester);
  });

  testWidgets('shows the unreported count and opens the export dialog', (
    tester,
  ) async {
    await repository.record(
      errorType: 'StateError',
      message: 'boom',
      stackTrace: 'line1\nline2',
    );
    await pumpIndicator(tester);
    await tester.pump();

    expect(find.text('أخطاء غير مُبلَّغ عنها (1)'), findsOneWidget);

    await tester.tap(find.text('أخطاء غير مُبلَّغ عنها (1)'));
    await tester.pumpAndSettle();

    expect(find.text('سجل الأخطاء المحلي'), findsOneWidget);
    expect(find.text('StateError'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    await unmountAndFlushDriftTimers(tester);
  });

  testWidgets('copy exports the plain-text report to the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await repository.record(
      errorType: 'StateError',
      message: 'boom',
      stackTrace: 'line1\nline2',
    );
    await pumpIndicator(tester);
    await tester.pump();

    await tester.tap(find.text('أخطاء غير مُبلَّغ عنها (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسخ التقرير'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(copied, isNotNull);
    expect(copied, contains('تقرير أخطاء التطبيق'));
    expect(copied, contains('boom'));
    expect(copied, contains('StateError'));
    expect(copied, contains('line1'));
    expect(find.text('تم نسخ تقرير الأخطاء إلى الحافظة'), findsOneWidget);
    await unmountAndFlushDriftTimers(tester);
  });

  testWidgets('marking reported clears the count and hides the indicator', (
    tester,
  ) async {
    await repository.record(errorType: 'StateError', message: 'boom');
    await pumpIndicator(tester);
    await tester.pump();
    expect(find.text('أخطاء غير مُبلَّغ عنها (1)'), findsOneWidget);

    await tester.tap(find.text('أخطاء غير مُبلَّغ عنها (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم التبليغ'));
    await tester.pumpAndSettle();

    expect(find.text('سجل الأخطاء المحلي'), findsNothing);
    expect(find.textContaining('أخطاء غير مُبلَّغ عنها'), findsNothing);
    await unmountAndFlushDriftTimers(tester);
  });
}