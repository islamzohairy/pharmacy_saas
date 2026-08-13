/// Tenant root entity. Plain domain object — no persistence knowledge.
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
    this.remoteUuid,
    this.taxRegistrationNumber,
    this.legalBusinessName,
    this.autoDeductStock = true,
  });

  final int id;
  final String name;

  /// ISO 4217 code. P0 always `EGP`.
  final String currency;
  final DateTime createdAt;

  /// Random v4 UUID generated at onboarding. The remote binding key for
  /// first-sync registration (register-first-wins) — local sequential
  /// ids are guessable across tenants, this must be random
  /// (DECISIONS.md).
  final String? remoteUuid;

  /// Compliance-prep fields (PLANS/10 Phase 4) — inert data capture for a
  /// future e-invoicing/ETA flow. Optional, no validation on write, and
  /// explicitly not part of any compliance feature today (COMPLIANCE.md).
  final String? taxRegistrationNumber;
  final String? legalBusinessName;

  /// Whether sales auto-post a `stock_out` movement for tracked products
  /// (PLANS/13 D6/D9). Default ON; the Settings toggle is the only write
  /// path.
  final bool autoDeductStock;
}
