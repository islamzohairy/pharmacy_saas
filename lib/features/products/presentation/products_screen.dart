import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/router/app_router.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// Product catalog (plan 05): live list of active products with
/// create/edit/soft-deactivate. Products are never hard-deleted — a
/// deactivated product hides from this list while its ledger history
/// stays valid.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final productsAsync = ref.watch(activeProductsProvider);

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
          onRetry: () => ref.invalidate(activeProductsProvider),
        ),
        data: (products) => products.isEmpty
            ? _ProductsEmpty(
                onAdd: () => context.pushNamed(AppRoutes.productForm),
              )
            : ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) =>
                    _ProductTile(product: products[index]),
              ),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(product.name),
      subtitle: Text(formatEgp(product.sellMinor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.editProduct,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.pushNamed(AppRoutes.productForm, extra: product),
          ),
          IconButton(
            tooltip: l10n.deactivateProduct,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeactivate(context, ref),
          ),
        ],
      ),
    );
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
