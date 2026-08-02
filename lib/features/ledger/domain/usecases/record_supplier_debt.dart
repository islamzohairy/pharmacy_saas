import '../../../../core/data/tables/ledger_entry_type.dart';
import '../ledger_entry.dart';
import '../ledger_repository.dart';

/// Records money owed to a supplier (stock bought on credit).
///
/// Pure use-case: validates the input, then writes exactly one append-only
/// `supplierDebt` ledger row through [repository]. [profileId] is the
/// active profile's id (attribution), resolved by the caller.
Future<LedgerEntry> recordSupplierDebt(
  LedgerRepository repository, {
  required int pharmacyId,
  required int supplierId,
  required int amountMinor,
  DateTime? occurredAt,
  int? profileId,
  String? note,
}) async {
  if (amountMinor <= 0) {
    throw ArgumentError.value(amountMinor, 'amountMinor', 'must be positive');
  }
  return repository.append(
    LedgerEntryDraft(
      pharmacyId: pharmacyId,
      type: LedgerEntryType.supplierDebt,
      amountMinor: amountMinor,
      supplierId: supplierId,
      occurredAt: occurredAt ?? DateTime.now(),
      profileId: profileId,
      note: note,
    ),
  );
}
