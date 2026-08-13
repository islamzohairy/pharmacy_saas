import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';
import 'package:pharmacy_saas/core/data/tables/stock_movement_type.dart';
import 'package:pharmacy_saas/features/activity/domain/activity_feed.dart';
import 'package:pharmacy_saas/features/activity/domain/activity_row.dart';
import 'package:pharmacy_saas/features/inventory/domain/stock_movement.dart';
import 'package:pharmacy_saas/features/ledger/domain/ledger_entry.dart';

/// mergeActivityFeed unit matrix (PLANS/13 §5.5 + D10): filter, ordering,
/// product-name join, attribution and the 100-combined cap.
void main() {
  const profileNames = {1: 'أم أحمد'};
  const productNames = {7: 'باراسيتامول 500'};

  LedgerEntry entry(int id, DateTime at, {int? profileId}) => LedgerEntry(
    id: id,
    pharmacyId: 4,
    type: LedgerEntryType.sale,
    amountMinor: 2550,
    productId: 7,
    occurredAt: at,
    profileId: profileId,
  );

  StockMovement movement(
    int id,
    DateTime at, {
    StockMovementType type = StockMovementType.stockIn,
    int quantity = 5,
    int? profileId,
  }) => StockMovement(
    id: id,
    pharmacyId: 4,
    productId: 7,
    type: type,
    quantity: quantity,
    occurredAt: at,
    profileId: profileId,
  );

  group('mergeActivityFeed', () {
    test('manual movements join entries sorted newest first', () {
      final rows = mergeActivityFeed(
        [entry(1, DateTime(2026, 8, 1, 10, 0))],
        [movement(2, DateTime(2026, 8, 1, 12, 0))],
        profileNames: profileNames,
        productNames: productNames,
      );

      expect(rows, hasLength(2));
      expect(rows[0], isA<MovementActivityRow>());
      expect(rows[1], isA<LedgerActivityRow>());
    });

    test('stock_out and initial are excluded (D10)', () {
      final rows = mergeActivityFeed(
        const [],
        [
          movement(1, DateTime(2026, 8, 1, 10, 0)),
          movement(
            2,
            DateTime(2026, 8, 1, 11, 0),
            type: StockMovementType.stockOut,
            quantity: -3,
          ),
          movement(
            3,
            DateTime(2026, 8, 1, 12, 0),
            type: StockMovementType.initial,
            quantity: 50,
          ),
          movement(
            4,
            DateTime(2026, 8, 1, 13, 0),
            type: StockMovementType.adjustment,
            quantity: -5,
          ),
        ],
        profileNames: profileNames,
        productNames: productNames,
      );

      expect(rows, hasLength(2));
      expect(rows[0].runtimeType, MovementActivityRow);
      expect((rows[0] as MovementActivityRow).movement.type,
          StockMovementType.adjustment);
      expect((rows[1] as MovementActivityRow).movement.type,
          StockMovementType.stockIn);
    });

    test('movements carry product name and recorder name', () {
      final rows = mergeActivityFeed(
        const [],
        [movement(1, DateTime(2026, 8, 1, 10, 0), profileId: 1)],
        profileNames: profileNames,
        productNames: productNames,
      );

      final row = rows.single as MovementActivityRow;
      expect(row.productName, 'باراسيتامول 500');
      expect(row.actorDisplayName, 'أم أحمد');
      // Unknown product id resolves to an empty name rather than crashing.
      final unknown = mergeActivityFeed(
        const [],
        [movement(2, DateTime(2026, 8, 1, 11, 0))],
        profileNames: const {},
        productNames: const {},
      );
      expect((unknown.single as MovementActivityRow).productName, '');
    });

    test('combined result is re-capped at 100 by recency', () {
      // Entries strictly newer than every movement (noon-domain vs
      // milliseconds after midnight) and strictly ordered within each
      // source, so the recency cut lands deterministically.
      final entries = [
        for (var i = 0; i < 60; i++)
          entry(i, DateTime(2026, 1, 1, 12).add(Duration(hours: i))),
      ];
      final movements = [
        for (var i = 0; i < 60; i++)
          movement(
            i,
            DateTime(2026, 1, 1).add(Duration(milliseconds: i + 1)),
          ),
      ];

      final rows = mergeActivityFeed(
        entries,
        movements,
        profileNames: profileNames,
        productNames: productNames,
      );

      expect(rows, hasLength(activityFeedCap));
      // All 60 entries are newer than all 60 movements, so entries fill
      // the top slots and the newest 40 movements take the rest.
      expect(rows.whereType<MovementActivityRow>(), hasLength(40));
      expect(rows.whereType<LedgerActivityRow>(), hasLength(60));
      var previous = rows.first.occurredAt;
      for (final row in rows.skip(1)) {
        expect(row.occurredAt.isBefore(previous) ||
            row.occurredAt.isAtSameMomentAs(previous), isTrue);
        previous = row.occurredAt;
      }
    });

    test('unattributed movements and entries resolve null actors', () {
      final rows = mergeActivityFeed(
        [entry(1, DateTime(2026, 8, 1, 10, 0))],
        [movement(2, DateTime(2026, 8, 1, 11, 0))],
        profileNames: profileNames,
        productNames: productNames,
      );
      expect(rows[0].actorDisplayName, isNull);
      expect(rows[1].actorDisplayName, isNull);
    });
  });
}