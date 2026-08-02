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
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final int pharmacyId;
  final String name;
  final int costMinor;
  final int sellMinor;
  final DateTime? expiryDate;
  final bool isActive;
  final DateTime? createdAt;

  Product copyWith({String? name, int? costMinor, int? sellMinor}) {
    return Product(
      id: id,
      pharmacyId: pharmacyId,
      name: name ?? this.name,
      costMinor: costMinor ?? this.costMinor,
      sellMinor: sellMinor ?? this.sellMinor,
      expiryDate: expiryDate,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
