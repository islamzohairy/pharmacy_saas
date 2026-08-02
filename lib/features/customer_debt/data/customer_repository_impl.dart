import 'package:drift/drift.dart';

import '../../../core/data/app_database.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

/// [CustomerRepository] backed by the local drift database.
class DriftCustomerRepository implements CustomerRepository {
  DriftCustomerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Customer> create({required int pharmacyId, required String name}) {
    return _db
        .into(_db.customers)
        .insertReturning(
          CustomersCompanion.insert(pharmacyId: pharmacyId, name: name),
        )
        .then(_toDomain);
  }

  @override
  Stream<List<Customer>> watchAll({required int pharmacyId}) {
    final query = _db.select(_db.customers)
      ..where((t) => t.pharmacyId.equals(pharmacyId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<Customer>> allCustomers({required int pharmacyId}) {
    final query = _db.select(_db.customers)
      ..where((t) => t.pharmacyId.equals(pharmacyId))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get().then((rows) => rows.map(_toDomain).toList());
  }

  Customer _toDomain(StoredCustomer row) => Customer(
    id: row.id,
    pharmacyId: row.pharmacyId,
    name: row.name,
    createdAt: row.createdAt,
  );
}
