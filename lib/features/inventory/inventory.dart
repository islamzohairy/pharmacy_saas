/// Public API of the inventory feature.
///
/// Other features import this barrel only — never this feature's internals
/// (no-cross-feature-internal-imports rule, GLOBAL_RULES.md).
library;

export '../../../core/data/tables/stock_movement_type.dart'
    show StockMovementType;
export 'data/stock_repository_impl.dart';
export 'domain/on_hand_reducer.dart';
export 'domain/stock_movement.dart';
export 'domain/stock_repository.dart';
export 'presentation/stock_adjustment_sheet.dart';
export 'presentation/stock_providers.dart';