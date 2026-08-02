import 'package:drift/drift.dart';

import '../../../core/data/app_database.dart';
import '../domain/supplier.dart';
import '../domain/supplier_repository.dart';

/// [SupplierRepository] backed by the local drift database.
class DriftSupplierRepository implements SupplierRepository {
  DriftSupplierRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Supplier> create({
    required int pharmacyId,
    required String name,
  }) {
    return _db
        .into(_db.suppliers)
        .insertReturning(
          SuppliersCompanion.insert(
            pharmacyId: pharmacyId,
            name: name,
          ),
        )
        .then(_toDomain);
  }

  @override
  Stream<List<Supplier>> watchAll({required int pharmacyId}) {
    final query = _db.select(_db.suppliers)
      ..where((t) => t.pharmacyId.equals(pharmacyId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<Supplier>> allSuppliers({required int pharmacyId}) {
    final query = _db.select(_db.suppliers)
      ..where((t) => t.pharmacyId.equals(pharmacyId))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get().then((rows) => rows.map(_toDomain).toList());
  }

  Supplier _toDomain(StoredSupplier row) => Supplier(
    id: row.id,
    pharmacyId: row.pharmacyId,
    name: row.name,
    createdAt: row.createdAt,
  );
}
