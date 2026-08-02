import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../../../core/streams/combine_latest.dart';
import '../../identity/identity.dart';
import '../../ledger/ledger.dart';
import '../data/supplier_repository_impl.dart';
import '../domain/supplier.dart';
import '../domain/supplier_repository.dart';

/// Drift-backed supplier repository.
final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => DriftSupplierRepository(ref.watch(appDatabaseProvider)),
);

/// A supplier joined with its live balance-owed figure.
class SupplierBalance {
  const SupplierBalance({required this.supplier, required this.owedMinor});

  final Supplier supplier;
  final int owedMinor;
}

/// Live suppliers with per-party balances, sorted non-zero first (largest
/// |balance| first), then by name — the actual "who do I owe" answer the
/// product exists to give.
///
/// Balances are computed with plan 04's [calculateOwedToSupplier] over the
/// two indexed type-filtered ledger streams (supplier_debt +
/// debt_repayment) — never stored, never clamped; a negative balance is a
/// legitimate credit and renders as such (PLANS/04, PLANS/06).
final supplierListWithBalancesProvider =
    StreamProvider.autoDispose<List<SupplierBalance>>((ref) {
      final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
      if (pharmacyId == null) return Stream.value(const []);
      final repository = ref.watch(ledgerRepositoryProvider);
      final combined = combineLatest3(
        ref.watch(supplierRepositoryProvider).watchAll(pharmacyId: pharmacyId),
        repository.watchEntries(
          pharmacyId: pharmacyId,
          type: LedgerEntryType.supplierDebt,
        ),
        repository.watchEntries(
          pharmacyId: pharmacyId,
          type: LedgerEntryType.debtRepayment,
        ),
      );
      return combined.map((parts) {
        final (suppliers, debts, repayments) = parts;
        final entries = [...debts, ...repayments];
        return suppliers
            .map(
              (supplier) => SupplierBalance(
                supplier: supplier,
                owedMinor: calculateOwedToSupplier(
                  entries: entries,
                  supplierId: supplier.id,
                ),
              ),
            )
            .toList()
          ..sort(_compareBalances);
      });
    });

int _compareBalances(SupplierBalance a, SupplierBalance b) {
  final aNonZero = a.owedMinor != 0;
  final bNonZero = b.owedMinor != 0;
  if (aNonZero != bNonZero) return aNonZero ? -1 : 1;
  if (aNonZero) {
    final byAbsolute = b.owedMinor.abs().compareTo(a.owedMinor.abs());
    if (byAbsolute != 0) return byAbsolute;
  }
  return a.supplier.name.compareTo(b.supplier.name);
}
