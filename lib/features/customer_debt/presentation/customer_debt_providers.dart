import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../../../core/streams/combine_latest.dart';
import '../../identity/identity.dart';
import '../../ledger/ledger.dart';
import '../data/customer_repository_impl.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

/// Drift-backed customer repository.
final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => DriftCustomerRepository(ref.watch(appDatabaseProvider)),
);

/// A customer joined with its live balance-owed figure.
class CustomerBalance {
  const CustomerBalance({required this.customer, required this.owedMinor});

  final Customer customer;
  final int owedMinor;
}

/// Live customers with per-party balances, sorted non-zero first (largest
/// |balance| first), then by name — the actual "who owes me" answer the
/// product exists to give.
///
/// Balances are computed with plan 04's [calculateOwedByCustomer] over the
/// two indexed type-filtered ledger streams (customer_debt +
/// debt_repayment) — never stored, never clamped; a negative balance is a
/// legitimate credit and renders as such (PLANS/04, PLANS/06).
final customerListWithBalancesProvider =
    StreamProvider.autoDispose<List<CustomerBalance>>((ref) {
      final pharmacyId = ref.watch(activeProfileProvider).value?.pharmacyId;
      if (pharmacyId == null) return Stream.value(const []);
      final repository = ref.watch(ledgerRepositoryProvider);
      final combined = combineLatest3(
        ref.watch(customerRepositoryProvider).watchAll(pharmacyId: pharmacyId),
        repository.watchEntries(
          pharmacyId: pharmacyId,
          type: LedgerEntryType.customerDebt,
        ),
        repository.watchEntries(
          pharmacyId: pharmacyId,
          type: LedgerEntryType.debtRepayment,
        ),
      );
      return combined.map((parts) {
        final (customers, debts, repayments) = parts;
        final entries = [...debts, ...repayments];
        return customers
            .map(
              (customer) => CustomerBalance(
                customer: customer,
                owedMinor: calculateOwedByCustomer(
                  entries: entries,
                  customerId: customer.id,
                ),
              ),
            )
            .toList()
          ..sort(_compareBalances);
      });
    });

int _compareBalances(CustomerBalance a, CustomerBalance b) {
  final aNonZero = a.owedMinor != 0;
  final bNonZero = b.owedMinor != 0;
  if (aNonZero != bNonZero) return aNonZero ? -1 : 1;
  if (aNonZero) {
    final byAbsolute = b.owedMinor.abs().compareTo(a.owedMinor.abs());
    if (byAbsolute != 0) return byAbsolute;
  }
  return a.customer.name.compareTo(b.customer.name);
}
