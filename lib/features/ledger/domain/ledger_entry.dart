import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';

/// A financial fact in the append-only ledger. Immutable once created.
///
/// Money is integer minor units (piastres), never float. The domain model
/// is a plain value object — no drift types leak out of the data layer.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.pharmacyId,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    this.productId,
    this.supplierId,
    this.customerId,
    this.profileId,
    this.note,
    this.syncedAt,
  });

  final int id;
  final int pharmacyId;
  final LedgerEntryType type;
  final int amountMinor;
  final DateTime occurredAt;
  final int? productId;
  final int? supplierId;
  final int? customerId;
  final int? profileId;
  final String? note;
  final DateTime? syncedAt;
}

/// Everything needed to create one new ledger row. The only write path
/// into the ledger is [LedgerRepository.append] with a draft — there is
/// no update, no delete, and no other insert.
class LedgerEntryDraft {
  const LedgerEntryDraft({
    required this.pharmacyId,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    this.productId,
    this.supplierId,
    this.customerId,
    this.profileId,
    this.note,
  });

  final int pharmacyId;
  final LedgerEntryType type;
  final int amountMinor;
  final DateTime occurredAt;
  final int? productId;
  final int? supplierId;
  final int? customerId;
  final int? profileId;
  final String? note;
}
