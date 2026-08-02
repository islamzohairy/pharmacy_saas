import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../data/supplier_repository_impl.dart';
import '../domain/supplier_repository.dart';

/// Drift-backed supplier repository.
final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => DriftSupplierRepository(ref.watch(appDatabaseProvider)),
);
