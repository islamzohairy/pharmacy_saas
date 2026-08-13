import 'product.dart';

/// Product catalog access.
///
/// Deletion rule (plan 05): products are **never hard-deleted** — once a
/// `sale` ledger entry references a product, that reference must stay
/// valid. Removal is [deactivate] (soft), which hides the product from
/// active listings while preserving history.
abstract interface class ProductRepository {
  Future<Product> create({
    required int pharmacyId,
    required String name,
    required int costMinor,
    required int sellMinor,
    DateTime? expiryDate,
    int? lowStockThreshold,
  });

  Future<Product> update(Product product);

  /// Soft-deactivates a product: row is retained, excluded from
  /// [watchActive].
  Future<void> deactivate(int productId);

  /// Live list of active products, newest first.
  Stream<List<Product>> watchActive({required int pharmacyId});

  /// Live list of **all** products for the pharmacy, deactivated ones
  /// included, newest first.
  ///
  /// Profit must resolve the cost of historical sales even after a
  /// product is soft-deactivated: COGS is read from `cost_minor` at
  /// calculation time, never stored in the ledger row (PLANS/04,
  /// PLANS/07) — the dashboard's cost map relies on this.
  Stream<List<Product>> watchAll({required int pharmacyId});

  Future<List<Product>> activeProducts({required int pharmacyId});
}
