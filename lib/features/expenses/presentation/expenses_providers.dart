import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/identity.dart';
import '../../ledger/ledger.dart';

/// Live, newest-first list of the pharmacy's expense entries — feeds the
/// "past expenses" section of the Expenses screen. Type-filtered to
/// [LedgerEntryType.expense]; category comes along on each row for
/// rendering. Never cached: recomputed from the ledger on every write
/// (PLANS/10 Phase 2).
final expenseEntriesProvider = StreamProvider.autoDispose<List<LedgerEntry>>(
  (ref) {
    final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
    if (pharmacyId == null) return Stream.value(const []);
    return ref
        .watch(ledgerRepositoryProvider)
        .watchEntries(pharmacyId: pharmacyId, type: LedgerEntryType.expense);
  },
);