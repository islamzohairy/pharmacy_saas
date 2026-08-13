import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../../identity/identity.dart';
import '../data/stock_repository_impl.dart';
import '../domain/stock_repository.dart';

/// Drift-backed stock movement repository.
final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => DriftStockRepository(ref.watch(appDatabaseProvider)),
);

/// Live on-hand map for every product of the active pharmacy. Empty while
/// no profile is active (unreachable after onboarding — defensive only).
final allOnHandProvider =
    StreamProvider.autoDispose<Map<int, int>>((ref) {
  final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
  if (pharmacyId == null) return Stream.value(const {});
  return ref
      .watch(stockRepositoryProvider)
      .watchAllOnHand(pharmacyId: pharmacyId);
});