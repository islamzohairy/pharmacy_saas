import '../../../../core/data/tables/ledger_entry_type.dart';
import '../ledger_entry.dart';
import '../ledger_repository.dart';

/// Records a debt repayment, either to a supplier or from a customer —
/// exactly one party must be given.
///
/// Pure use-case: validates the input, then writes exactly one append-only
/// `debtRepayment` ledger row through [repository]. [profileId] is the
/// active profile's id (attribution), resolved by the caller.
Future<LedgerEntry> recordRepayment(
  LedgerRepository repository, {
  required int pharmacyId,
  required int amountMinor,
  int? supplierId,
  int? customerId,
  DateTime? occurredAt,
  int? profileId,
  String? note,
}) async {
  if (amountMinor <= 0) {
    throw ArgumentError.value(amountMinor, 'amountMinor', 'must be positive');
  }
  if ((supplierId == null) == (customerId == null)) {
    throw ArgumentError(
      'exactly one of supplierId or customerId must be provided',
    );
  }
  return repository.append(
    LedgerEntryDraft(
      pharmacyId: pharmacyId,
      type: LedgerEntryType.debtRepayment,
      amountMinor: amountMinor,
      supplierId: supplierId,
      customerId: customerId,
      occurredAt: occurredAt ?? DateTime.now(),
      profileId: profileId,
      note: note,
    ),
  );
}
