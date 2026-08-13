import '../../../core/data/tables/stock_movement_type.dart';

/// A stock movement in the append-only movement ledger (PLANS/12 D1).
/// Immutable once created — a correction is a new offsetting movement,
/// never an edit of this one.
///
/// [quantity] is a signed integer delta in plain units (D4): positive
/// adds, negative subtracts. No minor units, no fractions.
///
/// The domain model is a plain value object — no drift types leak out of
/// the data layer.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.pharmacyId,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.occurredAt,
    this.profileId,
    this.note,
  });

  final int id;
  final int pharmacyId;
  final int productId;
  final StockMovementType type;

  /// Signed delta (positive adds, negative subtracts). `initial` and
  /// `stock_in` are positive, `stock_out` negative, `adjustment` carries
  /// the sign of the correction.
  final int quantity;

  final DateTime occurredAt;

  /// Caller-resolved attribution (plan-04 precedent); null for
  /// system-initiated movements.
  final int? profileId;

  final String? note;
}
