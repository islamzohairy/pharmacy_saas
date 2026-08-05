import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/database_providers.dart';
import 'package:pharmacy_saas/core/data/sync/backup_staleness.dart';
import 'package:pharmacy_saas/core/data/sync/sync_providers.dart';
import 'package:pharmacy_saas/core/data/sync/sync_scheduler.dart';
import 'package:pharmacy_saas/core/l10n/generated/app_localizations.dart';
import 'package:pharmacy_saas/core/widgets/backup_status_indicator.dart';
import 'package:pharmacy_saas/core/widgets/error_log_indicator.dart';

import '../../support/helpers.dart';

void main() {
  late BackupStatusNotifier status;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [backupStatusProvider.overrideWith((ref) => status)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BackupStatusIndicator()),
        ),
      ),
    );
    return container;
  }

  setUp(() {
    status = BackupStatusNotifier();
  });

  testWidgets('never synced state', (tester) async {
    await pump(tester);
    expect(find.text('لم تتم المزامنة بعد'), findsOneWidget);
  });

  testWidgets('syncing state', (tester) async {
    status.update(const BackupStatus(state: BackupSyncState.syncing));
    await pump(tester);
    expect(find.text('جارٍ النسخ الاحتياطي…'), findsOneWidget);
  });

  testWidgets('synced state shows the last backup time', (tester) async {
    status.update(
      BackupStatus(
        state: BackupSyncState.synced,
        lastSyncedAt: DateTime(2026, 8, 2, 15, 30),
      ),
    );
    await pump(tester);
    expect(find.textContaining('آخر نسخة:'), findsOneWidget);
    expect(find.textContaining('2/8/2026 15:30'), findsOneWidget);
  });

  testWidgets('error state', (tester) async {
    status.update(
      const BackupStatus(state: BackupSyncState.error, lastError: 'boom'),
    );
    await pump(tester);
    expect(find.text('تعذر النسخ الاحتياطي — سنحاول مرة أخرى'), findsOneWidget);
  });

  testWidgets('healthy staleness never shows the warning', (tester) async {
    status.update(
      BackupStatus(
        state: BackupSyncState.synced,
        lastSyncedAt: DateTime(2026, 8, 2, 15, 30),
        backlogCount: 0,
        staleness: BackupStaleness.healthy,
      ),
    );
    await pump(tester);
    expect(find.textContaining('نسخة احتياطية قديمة'), findsNothing);
  });

  testWidgets('pending staleness keeps the normal presentation', (tester) async {
    status.update(
      const BackupStatus(
        state: BackupSyncState.syncing,
        backlogCount: 3,
        staleness: BackupStaleness.pending,
      ),
    );
    await pump(tester);
    expect(find.text('جارٍ النسخ الاحتياطي…'), findsOneWidget);
    expect(find.textContaining('نسخة احتياطية قديمة'), findsNothing);
  });

  testWidgets('stale staleness shows the warning and opens the explanation '
      'dialog', (tester) async {
    status.update(
      const BackupStatus(
        state: BackupSyncState.error,
        backlogCount: 1,
        staleness: BackupStaleness.stale,
      ),
    );
    await pump(tester);
    expect(
      find.text('آخر نسخة احتياطية قديمة — تحقق من الاتصال'),
      findsOneWidget,
    );

    await tester.tap(find.text('آخر نسخة احتياطية قديمة — تحقق من الاتصال'));
    await tester.pumpAndSettle();

    expect(find.text('نسخة احتياطية قديمة'), findsOneWidget);
    expect(find.textContaining('لم تُنسخ احتياطيًا منذ أكثر من يومين'),
        findsOneWidget);

    // Non-destructive: the only action is dismissal.
    await tester.tap(find.text('فهمت'));
    await tester.pumpAndSettle();
    expect(find.text('نسخة احتياطية قديمة'), findsNothing);
  });

  testWidgets('stale warning and the error-log indicator coexist in RTL '
      'without clipping', (tester) async {
    final db = await createMemoryDb();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        backupStatusProvider.overrideWith((ref) => status),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    status.update(
      const BackupStatus(
        state: BackupSyncState.error,
        backlogCount: 2,
        staleness: BackupStaleness.stale,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorLogIndicator(),
                BackupStatusIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('آخر نسخة احتياطية قديمة — تحقق من الاتصال'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await unmountAndFlushDriftTimers(tester);
  });
}
