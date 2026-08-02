import 'supplier.dart';

/// Supplier party access. Deleting a supplier is blocked at the database
/// layer once any ledger entry references it (FK RESTRICT); the UI must
/// additionally warn when a balance is outstanding (plan 06).
abstract interface class SupplierRepository {
  Future<Supplier> create({required int pharmacyId, required String name});

  /// Live list of suppliers, newest first.
  Stream<List<Supplier>> watchAll({required int pharmacyId});

  Future<List<Supplier>> allSuppliers({required int pharmacyId});
}
