/// A party the pharmacy owes money to.
class Supplier {
  const Supplier({
    required this.id,
    required this.pharmacyId,
    required this.name,
    this.createdAt,
  });

  final int id;
  final int pharmacyId;
  final String name;
  final DateTime? createdAt;
}
