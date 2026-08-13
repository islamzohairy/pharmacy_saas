import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/streams/combine_latest.dart';
import '../../identity/identity.dart';
import '../../inventory/inventory.dart';
import '../../ledger/ledger.dart';
import '../../products/products.dart';
import '../domain/activity_feed.dart';
import '../domain/activity_row.dart';

/// Live newest-first activity feed for the active pharmacy (PLANS/10
/// Phase 3 + PLANS/13 §5.5): the last 100 ledger entries **and** the
/// last 100 stock movements (filtered to `stock_in`/`adjustment` — D10),
/// merged by recency and re-capped at 100 combined.
///
/// Product names join from the products stream so movement copy can name
/// the item; profile names are loaded once via
/// [IdentityRepository.getProfiles]. All sources are live drift streams
/// merged with combineLatest semantics — no polling, no new query logic.
final activityFeedProvider = StreamProvider.autoDispose<List<ActivityRow>>(
  (ref) async* {
    final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
    if (pharmacyId == null) {
      yield const [];
      return;
    }
    final profiles = await ref.watch(identityRepositoryProvider).getProfiles();
    final profileNames = {
      for (final profile in profiles) profile.id: profile.displayName,
    };
    final ledger = ref.watch(ledgerRepositoryProvider);
    final stock = ref.watch(stockRepositoryProvider);
    final products = ref.watch(productRepositoryProvider);
    yield* combineLatest3(
      ledger.watchEntries(pharmacyId: pharmacyId, limit: activityFeedCap),
      stock.watchMovements(pharmacyId: pharmacyId, limit: activityFeedCap),
      products.watchAll(pharmacyId: pharmacyId),
    ).map(
      (tuple) => mergeActivityFeed(
        tuple.$1,
        tuple.$2,
        profileNames: profileNames,
        productNames: {for (final product in tuple.$3) product.id: product.name},
      ),
    );
  },
);