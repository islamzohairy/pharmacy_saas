import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../data/product_repository_impl.dart';
import '../domain/product_repository.dart';

/// Drift-backed product repository.
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(ref.watch(appDatabaseProvider)),
);
