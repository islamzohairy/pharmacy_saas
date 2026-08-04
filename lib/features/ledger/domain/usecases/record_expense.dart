import '../../../../core/data/tables/expense_category.dart';
import '../../../../core/data/tables/ledger_entry_type.dart';
import '../ledger_entry.dart';
import '../ledger_repository.dart';

/// Records an expense — owner cash draw, rent, utilities, supplies, or
/// other (PLANS/10, PRODUCT_DIRECTION_FINAL.md item (b)).
///
/// Pure use-case: validates the input, then writes exactly one append-only
/// `expense` ledger row (with its [category]) through [repository].
/// [profileId] is the active profile's id (attribution); it is resolved by
/// the caller so this function stays free of provider dependencies.
Future<LedgerEntry> recordExpense(
  LedgerRepository repository, {
  required int pharmacyId,
  required ExpenseCategory category,
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
      type: LedgerEntryType.expense,
      amountMinor: amountMinor,
      category: category,
      occurredAt: occurredAt ?? DateTime.now(),
      profileId: profileId,
      note: note,
    ),
  );
}