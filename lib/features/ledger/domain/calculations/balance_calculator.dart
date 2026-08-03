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

/// Total currently owed to **all** suppliers combined:
/// sum(`supplierDebt`) − sum(`debtRepayment` entries referencing a
/// supplier). The dashboard's "who do I owe, total" figure (PLANS/07).
///
/// Accepts the pharmacy's full entry stream and ignores everything but
/// supplier-side entries. Mathematically equal to summing
/// [calculateOwedToSupplier] over every supplier, because each repayment
/// references exactly one party (validated at write, PLANS/04) — so this
/// total can never drift from what the plan 06 supplier screen shows.
/// Same live-derived, never-clamped semantics as the per-party version.
int calculateTotalOwedToSuppliers({required List<LedgerEntry> entries}) {
  var owedMinor = 0;
  for (final entry in entries) {
    owedMinor += switch (entry.type) {
      LedgerEntryType.supplierDebt => entry.amountMinor,
      LedgerEntryType.debtRepayment when entry.supplierId != null =>
        -entry.amountMinor,
      _ => 0,
    };
  }
  return owedMinor;
}

/// Total currently owed by **all** customers combined:
/// sum(`customerDebt`) − sum(`debtRepayment` entries referencing a
/// customer). The dashboard's "who owes me, total" figure (PLANS/07).
///
/// Mirror image of [calculateTotalOwedToSuppliers] — same live-derived,
/// never-clamped semantics; equal to summing [calculateOwedByCustomer]
/// over every customer.
int calculateTotalOwedByCustomers({required List<LedgerEntry> entries}) {
  var owedMinor = 0;
  for (final entry in entries) {
    owedMinor += switch (entry.type) {
      LedgerEntryType.customerDebt => entry.amountMinor,
      LedgerEntryType.debtRepayment when entry.customerId != null =>
        -entry.amountMinor,
      _ => 0,
    };
  }
  return owedMinor;
}
