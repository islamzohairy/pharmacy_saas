import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import '../domain/dashboard_range.dart';
import 'dashboard_providers.dart';

/// The date-range selector for the dashboard (PLANS/07 "File Structure
/// Impact"): today / this week / this month, defaulting to today.
///
/// Owns the [dashboardRangeProvider] state; the profit card recomputes
/// live because [dashboardProvider] watches the same state.
class DashboardRangeSelector extends ConsumerWidget {
  const DashboardRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SegmentedButton<DashboardRange>(
      segments: [
        ButtonSegment(
          value: DashboardRange.today,
          label: Text(l10n.dashboardRangeToday),
        ),
        ButtonSegment(
          value: DashboardRange.week,
          label: Text(l10n.dashboardRangeWeek),
        ),
        ButtonSegment(
          value: DashboardRange.month,
          label: Text(l10n.dashboardRangeMonth),
        ),
      ],
      selected: {ref.watch(dashboardRangeProvider)},
      onSelectionChanged: (selection) =>
          ref.read(dashboardRangeProvider.notifier).state = selection.single,
    );
  }
}
