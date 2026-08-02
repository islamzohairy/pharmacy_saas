import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/sync/sync_providers.dart';
import 'package:pharmacy_saas/core/data/sync/sync_scheduler.dart';
import 'package:pharmacy_saas/core/l10n/generated/app_localizations.dart';
import 'package:pharmacy_saas/core/widgets/backup_status_indicator.dart';

void main() {
  late BackupStatusNotifier status;

  Future<void> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        backupStatusProvider.overrideWith((ref) => status),
      ],
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
  }

  setUp(() {
    status = BackupStatusNotifier();
  });

  testWidgets('never synced state', (tester) async {
    await pump(tester);
    expect(find.text('لم تتم المزامنة بعد'), findsOneWidget);
  });

  testWidgets('syncing state', (tester) async {
    status.update(
      const BackupStatus(state: BackupSyncState.syncing),
    );
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
      const BackupStatus(
        state: BackupSyncState.error,
        lastError: 'boom',
      ),
    );
    await pump(tester);
    expect(find.text('تعذر النسخ الاحتياطي — سنحاول مرة أخرى'), findsOneWidget);
  });
}
