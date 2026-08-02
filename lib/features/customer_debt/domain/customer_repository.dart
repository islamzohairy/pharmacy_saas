import 'customer.dart';

/// Customer party access. Deleting a customer is blocked at the database
/// layer once any ledger entry references it (FK RESTRICT); the UI must
/// additionally warn when a balance is outstanding (plan 06).
abstract interface class CustomerRepository {
  Future<Customer> create({
    required int pharmacyId,
    required String name,
  });

  /// Live list of customers, newest first.
  Stream<List<Customer>> watchAll({required int pharmacyId});

  Future<List<Customer>> allCustomers({required int pharmacyId});
}
