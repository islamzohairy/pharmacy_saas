/// A product in the pharmacy's catalog. Money is integer minor units
/// (piastres), never float.
class Product {
  const Product({
    required this.id,
    required this.pharmacyId,
    required this.name,
    required this.costMinor,
    required this.sellMinor,
    this.expiryDate,
    this.lowStockThreshold,
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final int pharmacyId;
  final String name;
  final int costMinor;
  final int sellMinor;
  final DateTime? expiryDate;

  /// Optional low-stock signal threshold (PLANS/14, D15). This is
  /// configuration, never a stock movement — editing it posts nothing to
  /// the movement ledger.
  final int? lowStockThreshold;
  final bool isActive;
  final DateTime? createdAt;

  Product copyWith({
    String? name,
    int? costMinor,
    int? sellMinor,
    int? lowStockThreshold,
  }) {
    return Product(
      id: id,
      pharmacyId: pharmacyId,
      name: name ?? this.name,
      costMinor: costMinor ?? this.costMinor,
      sellMinor: sellMinor ?? this.sellMinor,
      expiryDate: expiryDate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
