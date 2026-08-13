import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/format/quantity.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/expense_category_labels.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/backup_status_indicator.dart';
import '../../../core/widgets/error_log_indicator.dart';
import '../domain/top_expense.dart';
import 'dashboard_providers.dart';
import 'dashboard_range_selector.dart';

/// The profit dashboard (PLANS/07) — the value-moment screen: "know where
/// your money goes, who owes you, and who you owe."
///
/// Pure read screen: every figure is freshly derived from the ledger via
/// plan 04's calculators (profit over the selected range, all-time debt
/// totals). No writes happen here, and nothing is cached — the screen
/// renders [DashboardData] and nothing else. Doubles as the app's
/// navigation hub to the five P0 feature screens.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dataAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoutes.settings),
          ),
          IconButton(
            tooltip: l10n.profilesTooltip,
            icon: const Icon(Icons.person),
            onPressed: () => context.goNamed(AppRoutes.profiles),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _DashboardError(onRetry: () => ref.invalidate(dashboardProvider)),
        data: (data) =>
            data.isEmpty ? const _DashboardEmpty() : _DashboardBody(data: data),
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorLogIndicator(),
              SizedBox(height: 4),
              BackupStatusIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The figures themselves: range selector, profit breakdown, debt totals
/// and the navigation hub. Deliberately logic-free — data arrives already
/// computed from [dashboardProvider].
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DashboardRangeSelector(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dashboardNetProfit,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  formatEgp(data.netMinor),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _FigureRow(
                  label: l10n.salesTitle,
                  amountMinor: data.salesMinor,
                ),
                const Divider(),
                _FigureRow(
                  label: l10n.dashboardCost,
                  amountMinor: data.costMinor,
                ),
                const Divider(),
                _FigureRow(
                  label: l10n.expensesTitle,
                  amountMinor: data.expensesMinor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (data.topExpense != null) ...[
          _ExpenseInsightLine(topExpense: data.topExpense!),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dashboardCurrentBalances,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                _FigureRow(
                  label: l10n.dashboardOwedToSuppliers,
                  amountMinor: data.owedToSuppliersMinor,
                ),
                const Divider(),
                _FigureRow(
                  label: l10n.dashboardOwedByCustomers,
                  amountMinor: data.owedByCustomersMinor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _NavTile(
                icon: Icons.point_of_sale,
                label: l10n.salesTitle,
                route: AppRoutes.sales,
              ),
              _NavTile(
                icon: Icons.inventory_2_outlined,
                label: l10n.productsTitle,
                route: AppRoutes.products,
                attentionCount: data.attentionCount,
              ),
              _NavTile(
                icon: Icons.receipt_long_outlined,
                label: l10n.expensesTitle,
                route: AppRoutes.expenses,
              ),
              _NavTile(
                icon: Icons.local_shipping_outlined,
                label: l10n.supplierDebtTitle,
                route: AppRoutes.supplierDebt,
              ),
              _NavTile(
                icon: Icons.people_outline,
                label: l10n.customerDebtTitle,
                route: AppRoutes.customerDebt,
              ),
              _NavTile(
                icon: Icons.history,
                label: l10n.activityTitle,
                route: AppRoutes.activity,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.label, required this.amountMinor});

  final String label;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Text(
          formatEgp(amountMinor),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _ExpenseInsightLine extends StatelessWidget {
  const _ExpenseInsightLine({required this.topExpense});

  final TopExpense topExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${l10n.topExpenseLabel}: '
            '${expenseCategoryLabel(l10n, topExpense.category)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            // Share of the range's total expenses (D16).
            '${formatEgp(topExpense.amountMinor)} '
            '(${formatQuantity(topExpense.sharePercent)}٪)',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
    this.attentionCount,
  });

  final IconData icon;
  final String label;
  final String route;

  /// Products-hub attention count (PLANS/14 §5.4): tracked products
  /// currently low or out of stock. The other five tiles pass null;
  /// hidden at zero.
  final int? attentionCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attentionCount != null && attentionCount! > 0)
            Tooltip(
              message: l10n.attentionCountTooltip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formatQuantity(attentionCount!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          const Icon(Icons.chevron_left),
        ],
      ),
      onTap: () => context.pushNamed(route),
    );
  }
}

/// First day of use: the ledger has no entries at all — an onboarding-
/// style nudge, not a wall of zeros (PLANS/07 edge case).
class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.dashboardEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.dashboardEmptyHint,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.sales),
              icon: const Icon(Icons.point_of_sale),
              label: Text(l10n.dashboardEmptyAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.loadError, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
