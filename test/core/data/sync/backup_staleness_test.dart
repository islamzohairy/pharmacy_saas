import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/sync/backup_staleness.dart';

void main() {
  final now = DateTime(2026, 8, 5, 12);

  BackupStaleness eval({
    int count = 0,
    DateTime? oldest,
    DateTime? at,
    Duration threshold = backupStaleThreshold,
  }) =>
      evaluateBackupStaleness(
        unsyncedCount: count,
        oldestUnsyncedAt: oldest,
        now: at ?? now,
        threshold: threshold,
      );

  test('no unsynced entries is healthy (fresh install never alarms)', () {
    expect(eval(), BackupStaleness.healthy);
  });

  test('unsynced entries all fresh are pending', () {
    expect(
      eval(count: 3, oldest: now.subtract(const Duration(hours: 1))),
      BackupStaleness.pending,
    );
  });

  test('unsynced entry older than the threshold is stale', () {
    expect(
      eval(
        count: 1,
        oldest: now.subtract(const Duration(hours: 49)),
      ),
      BackupStaleness.stale,
    );
  });

  test('exactly at the threshold boundary is still pending', () {
    expect(
      eval(count: 1, oldest: now.subtract(backupStaleThreshold)),
      BackupStaleness.pending,
    );
  });

  test('one hour past the threshold is stale', () {
    expect(
      eval(
        count: 1,
        oldest: now.subtract(backupStaleThreshold + const Duration(hours: 1)),
      ),
      BackupStaleness.stale,
    );
  });

  test('count without an oldest timestamp is defensively pending', () {
    expect(eval(count: 2, oldest: null), BackupStaleness.pending);
  });

  test('a clock set backward (negative age) masks staleness as pending', () {
    // Documented residual risk (DECISIONS.md 2026-08-05): a device clock
    // moved backward makes entries look fresh.
    expect(
      eval(count: 1, oldest: now.add(const Duration(days: 3))),
      BackupStaleness.pending,
    );
  });
}
