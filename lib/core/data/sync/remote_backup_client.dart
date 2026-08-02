/// One ledger row as the remote backup path sees it. Kept in `core` (not
/// the ledger feature) because the sync infrastructure lives in `core`
/// and must not depend on feature code.
class RemoteLedgerEntry {
  const RemoteLedgerEntry({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    this.productId,
    this.supplierId,
    this.customerId,
    this.profileId,
    this.note,
  });

  final int id;
  final String type;
  final int amountMinor;
  final DateTime occurredAt;
  final int? productId;
  final int? supplierId;
  final int? customerId;
  final int? profileId;
  final String? note;

  /// Field names must match `push_ledger_entries` in
  /// `supabase/migrations/0001_pharmacy_schema.sql`.
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'amount_minor': amountMinor,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    if (productId != null) 'product_id': productId,
    if (supplierId != null) 'supplier_id': supplierId,
    if (customerId != null) 'customer_id': customerId,
    if (profileId != null) 'profile_id': profileId,
    if (note != null) 'note': note,
  };
}

/// The remote backup surface. One implementation talks to Supabase; the
/// abstract shape is what keeps the sync job testable with a fake.
///
/// Security model (DECISIONS.md, SECURITY.md): every call is a
/// SECURITY DEFINER Postgres function on the server keyed by the
/// device's secret token. No direct table access ever reaches the anon
/// role, and the server derives the tenant from the token — never from
/// client-supplied ids.
abstract interface class RemoteBackupClient {
  /// Whether a backend is actually configured (build-time dart-defines).
  /// The job is a no-op when false.
  bool get isConfigured;

  /// Binds this install's token to its pharmacy on the server.
  /// Register-first-wins on `pharmacyUuid`.
  Future<void> registerDevice({
    required String deviceToken,
    required String pharmacyUuid,
    required String pharmacyName,
    required String currency,
  });

  /// Idempotent upsert keyed on `(pharmacy_id, id)` — retries never
  /// duplicate. Returns the number of rows inserted.
  Future<int> pushLedgerEntries({
    required String deviceToken,
    required List<RemoteLedgerEntry> entries,
  });
}
