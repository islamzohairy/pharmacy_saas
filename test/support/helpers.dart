import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/app_database.dart';
import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';

/// In-memory drift database — no SQLCipher needed in tests.
Future<AppDatabase> createMemoryDb() async {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a tenant row and returns its id.
Future<int> seedPharmacy(AppDatabase db, {String? remoteUuid}) async {
  return db
      .into(db.pharmacies)
      .insert(
        PharmaciesCompanion.insert(
          name: 'صيدلية النور',
          currency: 'EGP',
          remoteUuid: Value(remoteUuid ?? 'test-uuid-0000000000000000'),
        ),
      );
}

/// Seeds a profile row (the ledger's `profile_id` FK target) and returns
/// its id.
Future<int> seedProfile(AppDatabase db, int pharmacyId) {
  return db
      .into(db.userProfiles)
      .insert(
        UserProfilesCompanion.insert(
          pharmacyId: pharmacyId,
          role: 'owner',
          displayName: 'أم أحمد',
        ),
      );
}

/// Seeds an active product row and returns its id.
Future<int> seedProduct(
  AppDatabase db,
  int pharmacyId, {
  String? name,
  int costMinor = 2000,
  int sellMinor = 2550,
}) {
  return db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          pharmacyId: pharmacyId,
          name: name ?? 'باراسيتامول 500',
          costMinor: costMinor,
          sellMinor: sellMinor,
        ),
      );
}

/// Seeds a supplier row and returns its id.
Future<int> seedSupplier(AppDatabase db, int pharmacyId, {String? name}) {
  return db
      .into(db.suppliers)
      .insert(
        SuppliersCompanion.insert(
          pharmacyId: pharmacyId,
          name: name ?? 'مورد الأدوية',
        ),
      );
}

/// Seeds a customer row and returns its id.
Future<int> seedCustomer(AppDatabase db, int pharmacyId, {String? name}) {
  return db
      .into(db.customers)
      .insert(
        CustomersCompanion.insert(
          pharmacyId: pharmacyId,
          name: name ?? 'عميل الحي',
        ),
      );
}

/// Seeds one supplier-side ledger entry (debt or repayment) for the party.
Future<int> seedSupplierEntry(
  AppDatabase db,
  int pharmacyId,
  int supplierId, {
  required LedgerEntryType type,
  int amountMinor = 2500,
}) {
  return db
      .into(db.ledgerEntries)
      .insert(
        LedgerEntriesCompanion.insert(
          pharmacyId: pharmacyId,
          type: type,
          amountMinor: amountMinor,
          supplierId: Value(supplierId),
          occurredAt: DateTime.now(),
        ),
      );
}

/// Seeds one customer-side ledger entry (debt or repayment) for the party.
Future<int> seedCustomerEntry(
  AppDatabase db,
  int pharmacyId,
  int customerId, {
  required LedgerEntryType type,
  int amountMinor = 2500,
}) {
  return db
      .into(db.ledgerEntries)
      .insert(
        LedgerEntriesCompanion.insert(
          pharmacyId: pharmacyId,
          type: type,
          amountMinor: amountMinor,
          customerId: Value(customerId),
          occurredAt: DateTime.now(),
        ),
      );
}

/// Seeds one arbitrary ledger row with full control over party refs and
/// [occurredAt] — the dashboard's range tests seed sale/draw rows on
/// date boundaries that the party-specific seeders can't express.
Future<int> seedLedgerEntry(
  AppDatabase db,
  int pharmacyId, {
  required LedgerEntryType type,
  int amountMinor = 1000,
  int? productId,
  int? supplierId,
  int? customerId,
  DateTime? occurredAt,
}) {
  return db
      .into(db.ledgerEntries)
      .insert(
        LedgerEntriesCompanion.insert(
          pharmacyId: pharmacyId,
          type: type,
          amountMinor: amountMinor,
          productId: Value(productId),
          supplierId: Value(supplierId),
          customerId: Value(customerId),
          occurredAt: occurredAt ?? DateTime.now(),
        ),
      );
}

/// Unmounts the app and fires every drift close timer that provider disposal
/// schedules, inside the test body where fake_async can elapse them. Drift's
/// `StreamQueryStore.markAsClosed` schedules one zero-duration `Timer.run`
/// per canceled watch stream. Teardown — which runs in real async and cannot
/// elapse fake timers — unmounts the whole app and disposes every provider,
/// scheduling those timers; this helper unmounts early and interleaves
/// real-async progress (`runAsync`) with fake elapse (`pump`) so teardown
/// never sees a pending timer (the flutter_tester then wedges on
/// `Database.close()`/finalization and the test reports "did not complete").
///
/// Note: hub navigation is a push and the dashboard stays mounted beneath it
/// (DECISIONS.md 2026-08-03), so navigating alone no longer disposes the
/// autoDispose dashboard providers — calls after navigation are conservative
/// — but the flush is still required before teardown.
Future<void> unmountAndFlushDriftTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }
}
