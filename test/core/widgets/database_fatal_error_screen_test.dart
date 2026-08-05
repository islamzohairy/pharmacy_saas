import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/widgets/database_fatal_error_screen.dart';

void main() {
  const report = 'تقرير خطأ فتح البيانات\n'
      '----\n'
      '[5/8/2026 10:00] DatabaseOpenException\n'
      'database disk image is malformed';

  Widget app({required Future<void> Function() retry}) => DatabaseFatalErrorApp(
    report: report,
    retry: retry,
  );

  testWidgets('renders the Arabic non-destructive fatal screen', (
    tester,
  ) async {
    await tester.pumpWidget(app(retry: () async {}));

    expect(find.text('تعذر فتح البيانات'), findsOneWidget);
    expect(find.textContaining('بياناتك لم تُمس'), findsOneWidget);
    expect(find.text('نسخ التقرير'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    // Non-destructive by construction: the only actions are copy + retry.
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('copy puts the minimal report (no ledger content) on the '
      'clipboard', (tester) async {
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

    await tester.pumpWidget(app(retry: () async {}));
    await tester.tap(find.text('نسخ التقرير'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(copied, report);
    expect(copied, contains('DatabaseOpenException'));
    expect(find.text('تم نسخ التقرير إلى الحافظة'), findsOneWidget);
  });

  testWidgets('retry invokes the callback once and no automatic retry '
      'happens without a tap', (tester) async {
    var retries = 0;
    await tester.pumpWidget(app(retry: () async => retries++));

    await tester.pump(const Duration(seconds: 10));
    expect(retries, 0, reason: 'no automatic retry loops');

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('a failed retry keeps the screen and surfaces the failure', (
    tester,
  ) async {
    await tester.pumpWidget(app(retry: () async => throw StateError('still broken')));

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(find.text('تعذر فتح البيانات — حاول مرة أخرى'), findsOneWidget);
    expect(find.text('تعذر فتح البيانات'), findsOneWidget);
  });
}
