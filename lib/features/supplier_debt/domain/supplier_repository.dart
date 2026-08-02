import 'supplier.dart';

/// Supplier party access. There is no delete path in P0 by decision:
/// destructive deletion of a party is blocked (no UI affordance, and FK
/// RESTRICT at the database layer once any ledger entry references it);
/// soft deactivation is a deferred schema change (DECISIONS.md).
abstract interface class SupplierRepository {
  Future<Supplier> create({required int pharmacyId, required String name});

  /// Live list of suppliers, newest first.
  Stream<List<Supplier>> watchAll({required int pharmacyId});

  Future<List<Supplier>> allSuppliers({required int pharmacyId});
}
