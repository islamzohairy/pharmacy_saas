/// The date ranges the profit dashboard can display (PLANS/07).
///
/// [DashboardRange.today] is the default — the daily-logging habit the
/// MVP hypothesis is built to prove; it must be the first thing the
/// owner sees (PLANS/07 builder instructions).
enum DashboardRange { today, week, month }

/// Computes the inclusive `(from, to)` window for [range] as of [now].
///
/// Pure function with [now] injected so tests can pin any date: `to` is
/// always [now] (the ledger never holds future-dated entries — every
/// write stamps the current time), `from` is the range's start:
/// - today: midnight of [now]'s day;
/// - week: midnight of the most recent Saturday (Egyptian calendar
///   week start, ICU `ar_EG` convention — recorded in DECISIONS.md);
/// - month: midnight of the 1st of [now]'s month.
(DateTime, DateTime) rangeOf(DashboardRange range, DateTime now) {
  final dayStart = DateTime(now.year, now.month, now.day);
  return switch (range) {
    DashboardRange.today => (dayStart, now),
    DashboardRange.week => (_startOfWeek(now), now),
    DashboardRange.month => (DateTime(now.year, now.month), now),
  };
}

DateTime _startOfWeek(DateTime now) {
  // DateTime.monday == 1 ... DateTime.saturday == 6, DateTime.sunday == 7.
  // Days since the most recent Saturday:
  // Mon → 2, Tue → 3, ..., Sat → 0, Sun → 1.
  final daysSinceSaturday = (now.weekday + 1) % 7;
  final start = now.subtract(Duration(days: daysSinceSaturday));
  return DateTime(start.year, start.month, start.day);
}
