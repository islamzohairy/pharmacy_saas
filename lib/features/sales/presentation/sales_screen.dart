import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/error_log_providers.dart';
import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/router/app_router.dart';
import '../../identity/identity.dart';
import '../../inventory/inventory.dart';
import '../../ledger/ledger.dart';
import '../../products/products.dart';
import '../domain/record_sale_with_auto_deduct.dart';

/// Sales entry (plan 05): pick products, set quantities, confirm — one
/// scan-or-tap flow optimized for counter speed. Each line writes one
/// append-only `sale` ledger row at the current sell price; profit is
/// resolved from the product's cost at calculation time, never here.
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SaleLine {
  _SaleLine({required this.product});

  final Product product;
  int quantity = 1;
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _lines = <_SaleLine>[];
  final _searchController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalMinor => _lines.fold(
    0,
    (sum, line) => sum + line.product.sellMinor * line.quantity,
  );

  void _addProduct(Product product) {
    setState(() {
      final existing = _lines.where((l) => l.product.id == product.id);
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        _lines.add(_SaleLine(product: product));
      }
    });
  }

  void _setQuantity(_SaleLine line, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _lines.remove(line);
      } else {
        line.quantity = quantity;
      }
    });
  }

  Future<void> _confirmSale() async {
    final profile = ref.read(activeProfileProvider).value;
    final pharmacyId = profile?.pharmacyId;
    if (pharmacyId == null || _lines.isEmpty) return;

    setState(() => _saving = true);
    final ledger = ref.read(ledgerRepositoryProvider);
    final stock = ref.read(stockRepositoryProvider);
    final errorLog = ref.read(errorLogRepositoryProvider);
    try {
      // Fresh settings and on-hand read at confirm time, not at build:
      // toggling auto-deduct or tracking applies to the very next sale
      // (PLANS/13 §5.2, staff review item).
      final pharmacy =
          await ref.read(identityRepositoryProvider).getPharmacy();
      final onHand = await stock.allOnHand(pharmacyId: pharmacyId);
      for (final line in _lines) {
        await recordSaleWithAutoDeduct(
          ledger,
          stock,
          autoDeduct: pharmacy.autoDeductStock,
          isTracked: onHand.containsKey(line.product.id),
          pharmacyId: pharmacyId,
          productId: line.product.id,
          quantity: line.quantity,
          sellMinor: line.product.sellMinor,
          profileId: profile?.id,
          onStockFailure: () => errorLog.record(
            errorType: 'AutoDeductStock',
            message: 'Auto stock deduction failed for product '
                '${line.product.id} (pharmacy $pharmacyId); sale recorded, '
                'adjust stock manually.',
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _lines.clear();
        _searchController.clear();
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.saleRecorded)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.saleFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final productsAsync = ref.watch(activeProductsProvider);
    final products = productsAsync.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesTitle)),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.loadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(activeProductsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (_) => products.isEmpty
            ? _NoProducts(
                onGoToProducts: () => context.pushNamed(AppRoutes.products),
              )
            : Column(
                children: [
                  if (_lines.isNotEmpty) ...[
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _lines.length,
                        itemBuilder: (context, index) {
                          final line = _lines[index];
                          return _LineTile(
                            line: line,
                            onRemove: () => _setQuantity(line, 0),
                            onDecrease: () =>
                                _setQuantity(line, line.quantity - 1),
                            onIncrease: () =>
                                _setQuantity(line, line.quantity + 1),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchProducts,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final query = _searchController.text.trim();
                        if (query.isNotEmpty &&
                            !product.name.toLowerCase().contains(
                              query.toLowerCase(),
                            )) {
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(formatEgp(product.sellMinor)),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _addProduct(product),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l10n.totalLabel}: ${formatEgp(_totalMinor)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton(
                            onPressed: _lines.isEmpty || _saving
                                ? null
                                : _confirmSale,
                            child: Text(l10n.confirmSale),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onRemove,
    required this.onDecrease,
    required this.onIncrease,
  });

  final _SaleLine line;
  final VoidCallback onRemove;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      dense: true,
      title: Text(line.product.name),
      subtitle: Text(
        '${l10n.lineTotal}: ${formatEgp(line.product.sellMinor * line.quantity)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.decreaseQuantity,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDecrease,
          ),
          Text(
            '${line.quantity}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            tooltip: l10n.increaseQuantity,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onIncrease,
          ),
          IconButton(
            tooltip: l10n.removeLine,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _NoProducts extends StatelessWidget {
  const _NoProducts({required this.onGoToProducts});

  final VoidCallback onGoToProducts;

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
          Text(l10n.salesEmpty, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.salesEmptyHint,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onGoToProducts,
            child: Text(l10n.goToProducts),
          ),
        ],
      ),
    );
  }
}
