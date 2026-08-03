import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/features/dashboard/domain/dashboard_range.dart';

void main() {
  group('rangeOf', () {
    test('today spans from midnight to now', () {
      final now = DateTime(2026, 8, 3, 14, 30);

      final (from, to) = rangeOf(DashboardRange.today, now);

      expect(from, DateTime(2026, 8, 3));
      expect(to, now);
    });

    test('week starts on the most recent Saturday', () {
      // 2026-08-03 is a Monday → week start is Saturday 2026-08-01.
      final now = DateTime(2026, 8, 3, 9, 15);

      final (from, to) = rangeOf(DashboardRange.week, now);

      expect(from, DateTime(2026, 8, 1));
      expect(to, now);
    });

    test('week on a Saturday itself starts that same day', () {
      final saturday = DateTime(2026, 8, 1, 18);

      final (from, _) = rangeOf(DashboardRange.week, saturday);

      expect(from, DateTime(2026, 8, 1));
    });

    test('week rolls over the year boundary', () {
      // 2026-01-01 is a Thursday → week start is Saturday 2025-12-27.
      final now = DateTime(2026, 1, 1, 8);

      final (from, _) = rangeOf(DashboardRange.week, now);

      expect(from, DateTime(2025, 12, 27));
    });

    test('month starts on the first of the month', () {
      final now = DateTime(2026, 8, 15, 20, 45);

      final (from, to) = rangeOf(DashboardRange.month, now);

      expect(from, DateTime(2026, 8));
      expect(to, now);
    });
  });
}
