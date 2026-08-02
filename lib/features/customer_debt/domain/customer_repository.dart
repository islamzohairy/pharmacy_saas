import 'customer.dart';

/// Customer party access. There is no delete path in P0 by decision:
/// destructive deletion of a party is blocked (no UI affordance, and FK
/// RESTRICT at the database layer once any ledger entry references it);
/// soft deactivation is a deferred schema change (DECISIONS.md).
abstract interface class CustomerRepository {
  Future<Customer> create({required int pharmacyId, required String name});

  /// Live list of customers, newest first.
  Stream<List<Customer>> watchAll({required int pharmacyId});

  Future<List<Customer>> allCustomers({required int pharmacyId});
}
