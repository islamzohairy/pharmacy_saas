/// A party that owes money to the pharmacy.
class Customer {
  const Customer({
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
