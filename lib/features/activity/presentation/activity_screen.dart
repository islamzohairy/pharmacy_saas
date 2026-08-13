import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/format/quantity.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/expense_category_labels.dart';
import '../../inventory/inventory.dart';
import '../../ledger/ledger.dart';
import '../domain/activity_row.dart';
import 'activity_providers.dart';

/// Activity history (PLANS/10 Phase 3 + PLANS/13 §5.5): the last 100
/// ledger entries and manual stock movements, newest first, each labeled
/// with its amount/quantity and the profile that recorded it. Read-only —
/// the append-only rules mean there is nothing to edit here.
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
    return switch (row) {
      LedgerActivityRow(:final entry, :final actorDisplayName) => ListTile(
        leading: Icon(_iconFor(entry.type)),
        title: Text(_labelFor(l10n, entry)),
        subtitle: Text(
          [
            DateFormat('d/M/yyyy HH:mm').format(entry.occurredAt),
            if (actorDisplayName != null)
              l10n.activityRecordedBy(actorDisplayName),
          ].join(' · '),
        ),
        trailing: Text(
          formatEgp(entry.amountMinor),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      MovementActivityRow(
        :final movement,
        :final productName,
        :final actorDisplayName,
      ) =>
        ListTile(
          leading: Icon(_iconForMovement(movement.type)),
          title: Text(_labelForMovement(l10n, movement, productName)),
          subtitle: Text(
            [
              DateFormat('d/M/yyyy HH:mm').format(movement.occurredAt),
              if (actorDisplayName != null)
                l10n.activityRecordedBy(actorDisplayName),
            ].join(' · '),
          ),
          trailing: Text(
            _signedQuantity(movement.quantity),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
    };
  }

  /// Signed display quantity, e.g. `+5` → `+٥` and `-3` → `؜-٣` — the
  /// locale's digits and minus sign via the shared quantity formatter;
  /// positive values carry an explicit plus so direction never reads
  /// ambiguously in the feed.
  static String _signedQuantity(int quantity) => quantity >= 0
      ? '+${formatQuantity(quantity)}'
      : formatQuantity(quantity);

  IconData _iconFor(LedgerEntryType type) {
    return switch (type) {
      LedgerEntryType.sale => Icons.point_of_sale,
      LedgerEntryType.expense => Icons.receipt_long_outlined,
      LedgerEntryType.supplierDebt => Icons.local_shipping_outlined,
      LedgerEntryType.customerDebt => Icons.people_outline,
      LedgerEntryType.debtRepayment => Icons.currency_exchange,
    };
  }

  IconData _iconForMovement(StockMovementType type) {
    return switch (type) {
      StockMovementType.stockIn => Icons.add_box_outlined,
      // stock_out and initial never reach the feed (D10), but the
      // exhaustive switch needs a shape for them.
      StockMovementType.stockOut || StockMovementType.initial ||
      StockMovementType.adjustment =>
        Icons.build_outlined,
    };
  }

  String _labelForMovement(
    AppLocalizations l10n,
    StockMovement movement,
    String productName,
  ) {
    return switch (movement.type) {
      StockMovementType.stockIn => l10n.stockAddLabel(productName),
      StockMovementType.adjustment => l10n.stockAdjustLabel(productName),
      StockMovementType.stockOut || StockMovementType.initial =>
        movement.type.name,
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
    if (category == null) return l10n.ledgerTypeExpense;
    return expenseCategoryLabel(l10n, category);
  }
}