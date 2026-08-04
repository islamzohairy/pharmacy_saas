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
///
/// Exhaustive on purpose: Dart's `name` is camelCase (`cashDraw`) while
/// the remote whitelist is snake_case (`cash_draw`), and only `sale`
/// happens to match either way — a `=> name` getter silently sends values
/// the server rejects (PLANS/10 Phase 0). The compiler forces every new
/// type to declare its wire form here.
String get wireName => switch (this) {
  LedgerEntryType.sale => 'sale',
  LedgerEntryType.cashDraw => 'cash_draw',
  LedgerEntryType.supplierDebt => 'supplier_debt',
  LedgerEntryType.customerDebt => 'customer_debt',
  LedgerEntryType.debtRepayment => 'debt_repayment',
};
}
