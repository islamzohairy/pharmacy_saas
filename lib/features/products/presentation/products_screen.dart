import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/format/quantity.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/router/app_router.dart';
import '../../inventory/inventory.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// Product catalog (plan 05): live list of active products with
/// create/edit/soft-deactivate. Products are never hard-deleted — a
/// deactivated product hides from this list while its ledger history
/// stays valid. Each row also shows the live on-hand quantity
/// (PLANS/12 §5.4), joined from the stock-movement aggregate.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final productsAsync = ref.watch(productsWithOnHandProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.productsTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addProduct,
        onPressed: () => context.pushNamed(AppRoutes.productForm),
        child: const Icon(Icons.add),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProductsError(
          onRetry: () => ref.invalidate(productsWithOnHandProvider),
        ),
        data: (products) => products.isEmpty
            ? _ProductsEmpty(
                onAdd: () => context.pushNamed(AppRoutes.productForm),
              )
            : ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final (product, onHand) = products[index];
                  return _ProductTile(product: product, onHand: onHand);
                },
              ),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product, required this.onHand});

  final Product product;

  /// Live on-hand quantity for this product, or `null` when the product
  /// is **not tracked** (no movements at all) — displayed as a neutral
  /// "—", never as a false zero (staff-review finding, DECISIONS.md
  /// 2026-08-13).
  final int? onHand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final onHandStyle = (onHand ?? 0) < 0
        ? TextStyle(color: Theme.of(context).colorScheme.error)
        : null;
    return ListTile(
      // Tapping the row opens the stock/product action sheet — the
      // chevron trailing cues it (staff review item; PLANS/13 §5.3).
      onTap: () => _showActions(context, ref),
      title: _title(context),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatEgp(product.sellMinor)),
          // Not tracked → neutral "—" (stable layout, no structure shift
          // vs. tracked rows). Negative on-hand renders in a distinct
          // visual state with locale-correct digits — never clamped, no
          // warning dialog (D3; the signal treatment belongs to Plan 14).
          Text(
            onHand == null
                ? '${l10n.onHandLabel}: —'
                // Non-null in the else branch (public fields don't
                // promote — nullness already tested above).
                : '${l10n.onHandLabel}: ${formatQuantity(onHand!)}',
            style: onHandStyle,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.deactivateProduct,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeactivate(context, ref),
          ),
          // RTL-first app: the trailing edge is the left, where the
          // reading-direction chevron points left.
          const Icon(Icons.chevron_left),
        ],
      ),
    );
  }

  /// Product-row action sheet (PLANS/13 §5.3): stock adjustment, product
  /// edit, cancel. Replaces the old direct tap-to-edit.
  /// Name row with the stock-signal badge (PLANS/14 §5.3): the badge
  /// anchors on the title row so it never displaces the on-hand stock
  /// line or the row's tap affordance (staff UX watch-item). The signal
  /// is derived here — pure domain function [stockSignal], one source of
  /// truth shared with the dashboard attention count (D14).
  Widget _title(BuildContext context) {
    final signal = stockSignal(
      onHand: onHand,
      threshold: product.lowStockThreshold,
    );
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(product.name, overflow: TextOverflow.ellipsis),
        ),
        if (signal != StockSignal.none) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: switch (signal) {
                StockSignal.outOfStock => theme.colorScheme.errorContainer,
                StockSignal.low => theme.colorScheme.tertiaryContainer,
                StockSignal.none => null,
              },
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              signal == StockSignal.outOfStock
                  ? context.l10n.outOfStockBadge
                  : context.l10n.lowStockBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: switch (signal) {
                  StockSignal.outOfStock =>
                    theme.colorScheme.onErrorContainer,
                  StockSignal.low => theme.colorScheme.onTertiaryContainer,
                  StockSignal.none => null,
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<_ProductAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                product.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(l10n.adjustStockAction),
              onTap: () =>
                  Navigator.of(context).pop(_ProductAction.adjustStock),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editProductAction),
              onTap: () =>
                  Navigator.of(context).pop(_ProductAction.editDetails),
            ),
            ListTile(
              title: Text(l10n.cancel),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _ProductAction.adjustStock:
        await StockAdjustmentSheet.show(
          context,
          productId: product.id,
          productName: product.name,
          currentOnHand: onHand,
        );
      case _ProductAction.editDetails:
        await context.pushNamed(AppRoutes.productForm, extra: product);
      case null:
        break;
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deactivateProduct),
        content: Text(l10n.deactivateConfirmBody(product.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deactivateConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(productRepositoryProvider).deactivate(product.id);
    }
  }
}

/// Choice from the product-row action sheet (PLANS/13 §5.3).
enum _ProductAction { adjustStock, editDetails }

class _ProductsEmpty extends StatelessWidget {
  const _ProductsEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.productsEmpty,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.productsEmptyHint,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addProduct),
          ),
        ],
      ),
    );
  }
}

class _ProductsError extends StatelessWidget {
  const _ProductsError({required this.onRetry});

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
