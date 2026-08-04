import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../ledger/ledger.dart';
import '../domain/activity_row.dart';
import 'activity_providers.dart';

/// Activity history (PLANS/10 Phase 3): the last 100 ledger entries, newest
/// first, each labeled by type/category with its amount and the profile that
/// recorded it. Read-only — the ledger's append-only rule means there is
/// nothing to edit here.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final feed = ref.watch(activityFeedProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityTitle)),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.loadError, textAlign: TextAlign.center),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.activityEmpty,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) =>
                _ActivityTile(row: rows[index]),
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.row});

  final ActivityRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = row.entry;
    return ListTile(
      leading: Icon(_iconFor(entry.type)),
      title: Text(_labelFor(l10n, entry)),
      subtitle: Text(
        [
          DateFormat('d/M/yyyy HH:mm').format(entry.occurredAt),
          if (row.actorDisplayName != null)
            l10n.activityRecordedBy(row.actorDisplayName!),
        ].join(' · '),
      ),
      trailing: Text(
        formatEgp(entry.amountMinor),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  IconData _iconFor(LedgerEntryType type) {
    return switch (type) {
      LedgerEntryType.sale => Icons.point_of_sale,
      LedgerEntryType.expense => Icons.receipt_long_outlined,
      LedgerEntryType.supplierDebt => Icons.local_shipping_outlined,
      LedgerEntryType.customerDebt => Icons.people_outline,
      LedgerEntryType.debtRepayment => Icons.currency_exchange,
    };
  }

  String _labelFor(AppLocalizations l10n, LedgerEntry entry) {
    return switch (entry.type) {
      LedgerEntryType.sale => l10n.ledgerTypeSale,
      LedgerEntryType.expense =>
        _categoryLabel(l10n, entry.category),
      LedgerEntryType.supplierDebt => l10n.ledgerTypeSupplierDebt,
      LedgerEntryType.customerDebt => l10n.ledgerTypeCustomerDebt,
      LedgerEntryType.debtRepayment => l10n.debtRepaymentLabel,
    };
  }

  String _categoryLabel(AppLocalizations l10n, ExpenseCategory? category) {
    return switch (category) {
      ExpenseCategory.ownerDraw => l10n.expenseCategoryOwnerDraw,
      ExpenseCategory.rent => l10n.expenseCategoryRent,
      ExpenseCategory.utilities => l10n.expenseCategoryUtilities,
      ExpenseCategory.supplies => l10n.expenseCategorySupplies,
      ExpenseCategory.other => l10n.expenseCategoryOther,
      null => l10n.ledgerTypeExpense,
    };
  }
}