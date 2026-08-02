import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../data/customer_repository_impl.dart';
import '../domain/customer_repository.dart';

/// Drift-backed customer repository.
final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => DriftCustomerRepository(ref.watch(appDatabaseProvider)),
);
