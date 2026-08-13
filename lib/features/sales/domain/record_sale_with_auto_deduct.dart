import '../../inventory/inventory.dart';
import '../../ledger/ledger.dart';
import 'record_sale.dart';

/// Sale + auto-deduct coordination (PLANS/13 §5.2).
///
/// D8 ordering: the financial record is written FIRST and is never rolled
/// back. When [autoDeduct] is on and the product is tracked ([isTracked] —
/// the on-hand map's key-presence contract from Plan 12; absence = not
/// tracked), one `stock_out` movement of −[quantity] follows, attributed
/// to [profileId]. Untracked products are never deducted (D6).
///
/// A stock-write failure must not hide or block the sale: it is swallowed
/// here and reported through [onStockFailure] — the caller appends a
/// Plan-09 error-log entry; recovery is the manual adjustment sheet. A
/// failure of that report itself is swallowed too (a logging bug can't
/// surface as a sale failure — PLANS/09 capture-layer principle).
Future<void> recordSaleWithAutoDeduct(
  LedgerRepository ledger,
  StockRepository stock, {
  required bool autoDeduct,
  required bool isTracked,
  required int pharmacyId,
  required int productId,
  required int quantity,
  required int sellMinor,
  int? profileId,
  DateTime? occurredAt,
  Future<void> Function()? onStockFailure,
}) async {
  await recordSale(
    ledger,
    pharmacyId: pharmacyId,
    productId: productId,
    quantity: quantity,
    sellMinor: sellMinor,
    occurredAt: occurredAt,
    profileId: profileId,
  );
  if (!autoDeduct || !isTracked) return;
  try {
    await stock.recordMovement(
      pharmacyId: pharmacyId,
      productId: productId,
      type: StockMovementType.stockOut,
      quantity: -quantity,
      occurredAt: occurredAt ?? DateTime.now(),
      profileId: profileId,
    );
  } catch (_) {
    try {
      await onStockFailure?.call();
    } catch (_) {
      // Plan 09: the error-log capture layer never takes the app down.
    }
  }
}