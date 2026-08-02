import '../../../../core/data/tables/ledger_entry_type.dart';
import '../ledger_entry.dart';
import '../ledger_repository.dart';

/// Records an owner cash draw — money taken out of the pharmacy's cash.
///
/// Pure use-case: validates the input, then writes exactly one append-only
/// `cashDraw` ledger row through [repository]. [profileId] is the active
/// profile's id (attribution); it is resolved by the caller so this
/// function stays free of provider dependencies.
Future<LedgerEntry> recordDraw(
  LedgerRepository repository, {
  required int pharmacyId,
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
      type: LedgerEntryType.cashDraw,
      amountMinor: amountMinor,
      occurredAt: occurredAt ?? DateTime.now(),
      profileId: profileId,
      note: note,
    ),
  );
}
