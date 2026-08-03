import 'package:drift/drift.dart';

import '../../../core/data/app_database.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

/// [ProductRepository] backed by the local drift database.
class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Product> create({
    required int pharmacyId,
    required String name,
    required int costMinor,
    required int sellMinor,
    DateTime? expiryDate,
  }) {
    return _db
        .into(_db.products)
        .insertReturning(
          ProductsCompanion.insert(
            pharmacyId: pharmacyId,
            name: name,
            costMinor: costMinor,
            sellMinor: sellMinor,
            expiryDate: Value(expiryDate),
          ),
        )
        .then(_toDomain);
  }

  @override
  Future<Product> update(Product product) async {
    await (_db.update(
      _db.products,
    )..where((t) => t.id.equals(product.id))).write(
      ProductsCompanion(
        name: Value(product.name),
        costMinor: Value(product.costMinor),
        sellMinor: Value(product.sellMinor),
        expiryDate: Value(product.expiryDate),
      ),
    );
    return product;
  }

  @override
  Future<void> deactivate(int productId) {
    return (_db.update(_db.products)..where((t) => t.id.equals(productId)))
        .write(const ProductsCompanion(isActive: Value(false)));
  }

  @override
  Stream<List<Product>> watchActive({required int pharmacyId}) {
    final query = _db.select(_db.products)
      ..where((t) => t.pharmacyId.equals(pharmacyId) & t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<Product>> watchAll({required int pharmacyId}) {
    final query = _db.select(_db.products)
      ..where((t) => t.pharmacyId.equals(pharmacyId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<Product>> activeProducts({required int pharmacyId}) {
    final query = _db.select(_db.products)
      ..where((t) => t.pharmacyId.equals(pharmacyId) & t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get().then((rows) => rows.map(_toDomain).toList());
  }

  Product _toDomain(StoredProduct row) => Product(
    id: row.id,
    pharmacyId: row.pharmacyId,
    name: row.name,
    costMinor: row.costMinor,
    sellMinor: row.sellMinor,
    expiryDate: row.expiryDate,
    isActive: row.isActive,
    createdAt: row.createdAt,
  );
}
