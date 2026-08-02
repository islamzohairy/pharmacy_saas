/// Tenant root entity. Plain domain object — no persistence knowledge.
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
  });

  final int id;
  final String name;

  /// ISO 4217 code. P0 always `EGP`.
  final String currency;
  final DateTime createdAt;
}
