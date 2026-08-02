import '../../../../core/data/tables/ledger_entry_type.dart';
import '../ledger_entry.dart';

/// Amount currently owed to one supplier:
/// sum(`supplierDebt`) − sum(`debtRepayment`) for that supplier.
///
/// Always derived live from the ledger, never stored. A negative result is
/// a legitimate credit (overpayment) and is returned as-is, never clamped
/// to zero — clamping would silently hide money the owner might care
/// about (PLANS/04 edge cases). A supplier with no entries yields zero.
int calculateOwedToSupplier({
  required List<LedgerEntry> entries,
  required int supplierId,
}) {
  var owedMinor = 0;
  for (final entry in entries) {
    if (entry.supplierId != supplierId) continue;
    owedMinor += switch (entry.type) {
      LedgerEntryType.supplierDebt => entry.amountMinor,
      LedgerEntryType.debtRepayment => -entry.amountMinor,
      _ => 0,
    };
  }
  return owedMinor;
}

/// Amount one customer currently owes the pharmacy:
/// sum(`customerDebt`) − sum(`debtRepayment`) for that customer.
///
/// Same semantics as [calculateOwedToSupplier] — negative result is a
/// legitimate credit, never clamped.
int calculateOwedByCustomer({
  required List<LedgerEntry> entries,
  required int customerId,
}) {
  var owedMinor = 0;
  for (final entry in entries) {
    if (entry.customerId != customerId) continue;
    owedMinor += switch (entry.type) {
      LedgerEntryType.customerDebt => entry.amountMinor,
      LedgerEntryType.debtRepayment => -entry.amountMinor,
      _ => 0,
    };
  }
  return owedMinor;
}
