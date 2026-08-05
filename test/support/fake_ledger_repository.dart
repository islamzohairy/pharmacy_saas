import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_repository.dart';

/// In-memory [LedgerRepository] for use-case tests — no database needed.
///
/// Only [append] is implemented; the read/sync members are intentionally
/// unreachable from the use-cases and throw loudly if a test ever reaches
/// them, rather than silently returning empty data.
class FakeLedgerRepository implements LedgerRepository {
  final List<LedgerEntry> entries = [];
  int _nextId = 1;

  @override
  Future<LedgerEntry> append(LedgerEntryDraft draft) async {
    final entry = LedgerEntry(
      id: _nextId++,
      pharmacyId: draft.pharmacyId,
      type: draft.type,
      amountMinor: draft.amountMinor,
      productId: draft.productId,
      supplierId: draft.supplierId,
      customerId: draft.customerId,
      profileId: draft.profileId,
      occurredAt: draft.occurredAt,
      category: draft.category,
      note: draft.note,
    );
    entries.add(entry);
    return entry;
  }

  @override
  Future<void> markSynced({
    required int pharmacyId,
    required List<int> ids,
    required DateTime at,
  }) {
    throw UnimplementedError('markSynced is not used by the use-cases');
  }

  @override
  Future<List<LedgerEntry>> unsyncedEntries({
    required int pharmacyId,
    int limit = 200,
    List<int> excludeIds = const [],
  }) {
    throw UnimplementedError('unsyncedEntries is not used by the use-cases');
  }

  @override
  Stream<List<LedgerEntry>> watchEntries({
    required int pharmacyId,
    DateTime? from,
    DateTime? to,
    LedgerEntryType? type,
    int? limit,
  }) {
    throw UnimplementedError('watchEntries is not used by the use-cases');
  }

  @override
  Stream<List<LedgerEntry>> watchEntriesByParty({
    required int pharmacyId,
    required LedgerEntryType type,
    required int partyId,
  }) {
    throw UnimplementedError(
      'watchEntriesByParty is not used by the use-cases',
    );
  }

  @override
  Stream<int> watchUnsyncedCount({required int pharmacyId}) {
    throw UnimplementedError('watchUnsyncedCount is not used by the use-cases');
  }

  @override
  Future<DateTime?> oldestUnsyncedAt({required int pharmacyId}) {
    throw UnimplementedError('oldestUnsyncedAt is not used by the use-cases');
  }

  @override
  Future<DateTime?> lastSyncedAt({required int pharmacyId}) {
    throw UnimplementedError('lastSyncedAt is not used by the use-cases');
  }
}
