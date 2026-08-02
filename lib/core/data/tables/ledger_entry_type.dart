/// The five business facts a ledger entry can record. Defined at the
/// schema layer (not in a feature) because `core/` must not import feature
/// code — the ledger feature re-exposes it through its domain barrel.
enum LedgerEntryType {
  sale,
  cashDraw,
  supplierDebt,
  customerDebt,
  debtRepayment;

  /// Server-side whitelist of accepted remote values (migrations/
  /// 0001_pharmacy_schema.sql must stay in sync with this).
  String get wireName => name;
}
