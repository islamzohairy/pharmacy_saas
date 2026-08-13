import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../../../core/streams/combine_latest.dart';
import '../../identity/identity.dart';
import '../../inventory/inventory.dart';
import '../data/product_repository_impl.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

/// Drift-backed product repository.
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(ref.watch(appDatabaseProvider)),
);

/// Live list of active products for the active pharmacy. Empty while no
/// profile is active (unreachable after onboarding — defensive only).
final activeProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
  if (pharmacyId == null) return Stream.value(const []);
  return ref
      .watch(productRepositoryProvider)
      .watchActive(pharmacyId: pharmacyId);
});

/// Active products joined with their live on-hand quantity (PLANS/12
/// §5.4), computed from the grouped stock-movement aggregate — one
/// stream per source, merged with combineLatest semantics. Products with
/// no movements yield on-hand 0.
final productsWithOnHandProvider =
    StreamProvider.autoDispose<List<(Product, int)>>((ref) {
  final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
  if (pharmacyId == null) return Stream.value(const []);
  final products = ref
      .watch(productRepositoryProvider)
      .watchActive(pharmacyId: pharmacyId);
  final onHandByProduct = ref
      .watch(stockRepositoryProvider)
      .watchAllOnHand(pharmacyId: pharmacyId);
  return combineLatest2(products, onHandByProduct).map(
    (tuple) {
      final (productRows, onHandMap) = tuple;
      return [
        for (final product in productRows)
          (product, onHandMap[product.id] ?? 0),
      ];
    },
  );
});