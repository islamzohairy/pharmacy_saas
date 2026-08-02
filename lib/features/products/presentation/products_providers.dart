import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../../identity/identity.dart';
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
