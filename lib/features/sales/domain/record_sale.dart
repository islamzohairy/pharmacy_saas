import '../../ledger/ledger.dart';

/// Records a sale of one product at [quantity] units, priced at
/// [sellMinor] per unit.
///
/// Pure use-case, same shape as plan 04's actions: validates the input,
/// computes `amountMinor = sellMinor × quantity` in the domain layer (no
/// calculation logic lives in the widget), then writes exactly one
/// append-only `sale` ledger row through [repository]. [profileId] is the
/// active profile's id (attribution), resolved by the caller.
///
/// The sale amount is derived from the current sell price at entry time —
/// the ledger stores what happened, not a duplicated snapshot of the
/// product (PLANS/05). Cost is never read here; profit resolves it from
/// `products.cost_minor` at calculation time (PLANS/04).
Future<LedgerEntry> recordSale(
  LedgerRepository repository, {
  required int pharmacyId,
  required int productId,
  required int quantity,
  required int sellMinor,
  DateTime? occurredAt,
  int? profileId,
  String? note,
}) async {
  if (quantity <= 0) {
    throw ArgumentError.value(quantity, 'quantity', 'must be positive');
  }
  if (sellMinor <= 0) {
    throw ArgumentError.value(sellMinor, 'sellMinor', 'must be positive');
  }
  return repository.append(
    LedgerEntryDraft(
      pharmacyId: pharmacyId,
      type: LedgerEntryType.sale,
      amountMinor: sellMinor * quantity,
      productId: productId,
      occurredAt: occurredAt ?? DateTime.now(),
      profileId: profileId,
      note: note,
    ),
  );
}
