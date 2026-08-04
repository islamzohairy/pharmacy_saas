import 'package:drift/drift.dart';

/// Tenant root. One row per install for P0 — `pharmacy_id` on every other
/// table is what makes tenant isolation load-bearing from the first
/// migration (ARCHITECTURE.md).
///
/// `remoteUuid` is a random UUID generated at onboarding, used to bind the
/// device to its remote tenant at first sync (register-first-wins). Local
/// sequential ids are guessable across tenants, so the remote binding key
/// must be random — see DECISIONS.md.
///
/// `@DataClassName` keeps the generated data class distinct from the
/// domain `Pharmacy` entity.
@DataClassName('StoredPharmacy')
class Pharmacies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get remoteUuid => text().nullable()();

  /// Compliance-prep data capture (PLANS/10 Phase 4, PRODUCT_DIRECTION_
  /// FINAL.md item (d)): inert fields for future e-invoicing integration.
  /// Deliberately NOT compliance implementation — the ETA item stays
  /// behind COMPLIANCE.md's confirmed-by-counsel gate.
  TextColumn get taxRegistrationNumber => text().nullable()();
  TextColumn get legalBusinessName => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
