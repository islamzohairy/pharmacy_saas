import '../../inventory/inventory.dart';
import '../../ledger/ledger.dart';

/// One row of the activity feed (PLANS/10 Phase 3 + PLANS/13 §5.5):
/// either a ledger entry or a manual stock movement, each joined with
/// the display name of the profile that recorded it (when attribution
/// exists).
///
/// Localized label selection is a presentation concern (l10n keys by
/// type/category/kind), so it stays out of these helpers.
sealed class ActivityRow {
  const ActivityRow({this.actorDisplayName});

  /// Timestamp used for feed ordering — each subclass derives it from
  /// its own payload.
  DateTime get occurredAt;

  /// Display name of the recording profile, or null when unattributed
  /// or unknown.
  final String? actorDisplayName;
}

/// A ledger row: the entry carries the financial facts.
class LedgerActivityRow extends ActivityRow {
  const LedgerActivityRow({required this.entry, super.actorDisplayName});

  final LedgerEntry entry;

  @override
  DateTime get occurredAt => entry.occurredAt;

  /// Resolves the recorder's name from [profileNames]
  /// (profileId → displayName).
  factory LedgerActivityRow.fromEntry(
    LedgerEntry entry,
    Map<int, String> profileNames,
  ) {
    final profileId = entry.profileId;
    return LedgerActivityRow(
      entry: entry,
      actorDisplayName: profileId == null ? null : profileNames[profileId],
    );
  }
}

/// A manual stock-movement row. Only `stock_in` and `adjustment` reach
/// the feed (D10 — auto `stock_out` and `initial` are deliberately
/// absent); the product name is joined at provider time so the copy can
/// name the item.
class MovementActivityRow extends ActivityRow {
  const MovementActivityRow({
    required this.movement,
    required this.productName,
    super.actorDisplayName,
  });

  final StockMovement movement;
  final String productName;

  @override
  DateTime get occurredAt => movement.occurredAt;

  /// Resolves the recorder's and the product's names from their
  /// id→name maps.
  factory MovementActivityRow.fromMovement(
    StockMovement movement,
    Map<int, String> profileNames,
    Map<int, String> productNames,
  ) {
    final profileId = movement.profileId;
    return MovementActivityRow(
      movement: movement,
      productName: productNames[movement.productId] ?? '',
      actorDisplayName: profileId == null ? null : profileNames[profileId],
    );
  }
}