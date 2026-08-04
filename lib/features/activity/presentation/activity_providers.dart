import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/identity.dart';
import '../../ledger/ledger.dart';
import '../domain/activity_row.dart';

/// Live newest-first activity feed for the active pharmacy: the last 100
/// ledger entries, each joined with its recorder's display name.
///
/// Profile names are loaded once via [IdentityRepository.getProfiles]; the
/// entry stream itself is the same indexed `watchEntries` every feature
/// uses — no new query logic (PLANS/10 Phase 3).
final activityFeedProvider = StreamProvider.autoDispose<List<ActivityRow>>(
  (ref) async* {
    final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
    if (pharmacyId == null) {
      yield const [];
      return;
    }
    final identityRepository = ref.watch(identityRepositoryProvider);
    final ledgerRepository = ref.watch(ledgerRepositoryProvider);
    final profiles = await identityRepository.getProfiles();
    final profileNames = {
      for (final profile in profiles) profile.id: profile.displayName,
    };
    yield* ledgerRepository
        .watchEntries(pharmacyId: pharmacyId, limit: 100)
        .map(
          (entries) => [
            for (final entry in entries)
              ActivityRow.fromEntry(entry, profileNames),
          ],
        );
  },
);