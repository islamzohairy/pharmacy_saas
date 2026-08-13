import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/tables/stock_movement_type.dart'
    show StockMovementType;
import '../../../core/format/money.dart' show normalizeDigits;
import '../../../core/format/quantity.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../identity/identity.dart';
import 'stock_providers.dart';

/// Split mode of the adjustment sheet (PLANS/13 §5.3).
enum StockAdjustMode {
  /// Post a positive `stock_in`: quantity = entered value.
  add,

  /// Post a signed `adjustment` delta to reach an exact target: entered
  /// value is the target, delta = target − current (current = 0 when
  /// the product is untracked).
  correct,
}

/// Manual stock adjustment (PLANS/13 §5.3): the inventory feature's own
/// two-mode sheet, launched from the product-row action sheet.
///
/// Add mode posts `stock_in` with the entered positive quantity; correct
/// mode posts a signed `adjustment` delta toward the entered target.
/// A zero delta disables commit with an inline "no change" state (D7).
/// The movement is attributed to the active profile, resolved here
/// (plan-04 precedent). Product data travels as ids + name so this
/// feature never depends on another feature's internals.
class StockAdjustmentSheet extends ConsumerStatefulWidget {
  const StockAdjustmentSheet({
    super.key,
    required this.productId,
    required this.productName,
    this.currentOnHand,
  });

  final int productId;
  final String productName;

  /// On-hand at open, or `null` when the product is not tracked (no
  /// movements) — displayed as a neutral "—"; correction math treats
  /// an absent quantity as 0.
  final int? currentOnHand;

  /// Opens the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required int productId,
    required String productName,
    int? currentOnHand,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StockAdjustmentSheet(
        productId: productId,
        productName: productName,
        currentOnHand: currentOnHand,
      ),
    );
  }

  @override
  ConsumerState<StockAdjustmentSheet> createState() =>
      _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends ConsumerState<StockAdjustmentSheet> {
  StockAdjustMode _mode = StockAdjustMode.add;
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Shared digit path (PLANS/12 V3): Arabic-Indic input normalizes to
  /// Western digits before parsing — one convention, no second parser.
  int? get _parsed {
    final raw = _quantityController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(normalizeDigits(raw));
  }

  /// Current on-hand, defaulting an untracked product to 0 (D7).
  int get _current => widget.currentOnHand ?? 0;

  /// Signed adjustment delta in correct mode.
  int get _delta => (_parsed ?? 0) - _current;

  bool get _valueValid {
    final value = _parsed;
    if (value == null) return false;
    return _mode == StockAdjustMode.add ? value >= 1 : value >= 0;
  }

  bool get _commitEnabled =>
      _valueValid && (_mode == StockAdjustMode.add || _delta != 0) && !_saving;

  /// Validation state shown under the field (reuses the shared
  /// whole-number copy); silent while the field is empty.
  bool get _showError {
    final raw = _quantityController.text.trim();
    if (raw.isEmpty) return false;
    return !_valueValid;
  }

  Future<void> _commit() async {
    final profile = ref.read(activeProfileProvider).value;
    final pharmacyId = profile?.pharmacyId;
    final value = _parsed;
    if (pharmacyId == null || value == null || !_commitEnabled) return;

    setState(() => _saving = true);
    try {
      final isAdd = _mode == StockAdjustMode.add;
      await ref.read(stockRepositoryProvider).recordMovement(
        pharmacyId: pharmacyId,
        productId: widget.productId,
        type: isAdd ? StockMovementType.stockIn : StockMovementType.adjustment,
        // Add posts the entered quantity; correct posts the signed delta
        // toward the target (negative allowed — correction can reduce).
        quantity: isAdd ? value : _delta,
        occurredAt: DateTime.now(),
        profileId: profile?.id,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.stockUpdateFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = _parsed;
    final inError = _showError;
    final showNoChange = _mode == StockAdjustMode.correct &&
        value != null &&
        _delta == 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.productName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('${l10n.currentOnHandLabel}: ${widget.currentOnHand == null ? '—' : formatQuantity(widget.currentOnHand!)}'),
              const SizedBox(height: 16),
              SegmentedButton<StockAdjustMode>(
                segments: [
                  ButtonSegment(
                    value: StockAdjustMode.add,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addQuantity),
                  ),
                  ButtonSegment(
                    value: StockAdjustMode.correct,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.correctQuantity),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _saving
                    ? null
                    : (selection) =>
                          setState(() => _mode = selection.single),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: l10n.quantityLabel,
                  errorText: inError ? l10n.initialStockInvalid : null,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (showNoChange)
                Text(
                  l10n.noChange,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                )
              else if (value != null && _valueValid)
                Text(
                  _mode == StockAdjustMode.add
                      ? l10n.afterAddPreview(
                          formatQuantity(_current + value),
                        )
                      : l10n.correctPreview(
                          formatQuantity(_delta),
                          formatQuantity(value),
                        ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(labelText: l10n.noteOptional),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _commitEnabled ? _commit : null,
                  child: Text(l10n.updateStock),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}