import '../../../../core/data/tables/ledger_entry_type.dart';
import '../ledger_entry.dart';
import '../ledger_repository.dart';

/// Records money a customer owes the pharmacy (credit sales).
///
/// Pure use-case: validates the input, then writes exactly one append-only
/// `customerDebt` ledger row through [repository]. [profileId] is the
/// active profile's id (attribution), resolved by the caller.
Future<LedgerEntry> recordCustomerDebt(
  LedgerRepository repository, {
  required int pharmacyId,
  required int customerId,
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
      type: LedgerEntryType.customerDebt,
      amountMinor: amountMinor,
      customerId: customerId,
      occurredAt: occurredAt ?? DateTime.now(),
      profileId: profileId,
      note: note,
    ),
  );
}
