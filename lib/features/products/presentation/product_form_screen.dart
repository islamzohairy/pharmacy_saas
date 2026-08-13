import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../identity/identity.dart';
import '../../inventory/inventory.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// Product create/edit form (plan 05). Expiry date is truly optional —
/// no validation forces it. Cost and sell prices are required and must be
/// positive: a sale of a product with no cost would silently misstate
/// profit, so it is blocked here, never allowed (PLANS/05 edge cases).
/// Initial stock (PLANS/12 §5.3) is an optional integer field on
/// **creation only** — editing never touches stock; a non-empty value
/// posts exactly one `initial` stock movement on create.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  /// When null the form creates a new product; otherwise it edits this one.
  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _costController;
  late final TextEditingController _sellController;
  late final TextEditingController _initialStockController;
  DateTime? _expiryDate;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _costController = TextEditingController(
      text: product == null ? '' : _formatPriceInput(product.costMinor),
    );
    _sellController = TextEditingController(
      text: product == null ? '' : _formatPriceInput(product.sellMinor),
    );
    // Initial stock exists only on creation (PLANS/12 §5.3): editing a
    // product never touches stock — a fresh movement on edit would
    // double-count the catalog's opening balance.
    _initialStockController = TextEditingController();
    _expiryDate = product?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _sellController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  /// Shows a price the user can re-edit cleanly (no thousands separators,
  /// Western digits) regardless of the display locale.
  static String _formatPriceInput(int minorUnits) {
    final fraction = (minorUnits % 100).toString().padLeft(2, '0');
    return '${minorUnits ~/ 100}.$fraction';
  }

  String? _priceValidator(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return context.l10n.priceRequired;
    try {
      if (parseEgpToMinor(raw) <= 0) {
        return context.l10n.priceMustBePositive;
      }
    } on FormatException {
      return context.l10n.priceInvalid;
    }
    return null;
  }

  /// Parses the optional initial-stock input: empty → `null` (no
  /// movement), otherwise a non-negative integer with Arabic-Indic
  /// digits accepted through the shared [normalizeDigits] path — no
  /// second parsing convention (PLANS/12 V3, §5.3).
  int? _parseInitialStock(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(normalizeDigits(trimmed));
  }

  String? _initialStockValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = _parseInitialStock(value);
    if (parsed == null || parsed < 0) {
      return context.l10n.initialStockInvalid;
    }
    return null;
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final costMinor = parseEgpToMinor(_costController.text.trim());
    final sellMinor = parseEgpToMinor(_sellController.text.trim());

    final profile = ref.read(activeProfileProvider).value;
    final pharmacyId = profile?.pharmacyId ?? widget.product?.pharmacyId;
    if (pharmacyId == null) return;

    setState(() => _saving = true);
    final repository = ref.read(productRepositoryProvider);
    if (_isEditing) {
      final product = widget.product!;
      await repository.update(
        Product(
          id: product.id,
          pharmacyId: product.pharmacyId,
          name: name,
          costMinor: costMinor,
          sellMinor: sellMinor,
          expiryDate: _expiryDate,
          isActive: product.isActive,
          createdAt: product.createdAt,
        ),
      );
    } else {
      final product = await repository.create(
        pharmacyId: pharmacyId,
        name: name,
        costMinor: costMinor,
        sellMinor: sellMinor,
        expiryDate: _expiryDate,
      );
      // Optional initial stock → exactly one `initial` movement on
      // creation, attributed to the active profile. Empty or zero posts
      // nothing — on-hand defaults to 0 (PLANS/12 §9). Never on edit.
      final initialStock = _parseInitialStock(
        _initialStockController.text,
      );
      if (initialStock != null && initialStock > 0) {
        await ref.read(stockRepositoryProvider).recordMovement(
          pharmacyId: pharmacyId,
          productId: product.id,
          type: StockMovementType.initial,
          quantity: initialStock,
          occurredAt: DateTime.now(),
          profileId: profile?.id,
        );
      }
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editProduct : l10n.addProduct),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.productNameLabel),
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.productNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costController,
              decoration: InputDecoration(
                labelText: l10n.costPriceLabel,
                helperText: l10n.priceHelper,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _priceValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sellController,
              decoration: InputDecoration(
                labelText: l10n.sellPriceLabel,
                helperText: l10n.priceHelper,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _priceValidator,
            ),
            const SizedBox(height: 16),
            if (!_isEditing) ...[
              TextFormField(
                controller: _initialStockController,
                decoration: InputDecoration(
                  labelText: l10n.initialStockLabel,
                  helperText: l10n.initialStockOptional,
                ),
                keyboardType: TextInputType.number,
                validator: _initialStockValidator,
              ),
              const SizedBox(height: 16),
            ],
            InputDecorator(
              isEmpty: _expiryDate == null,
              decoration: InputDecoration(
                labelText: l10n.expiryDateLabel,
                suffixIcon: _expiryDate == null
                    ? null
                    : IconButton(
                        tooltip: l10n.clearExpiry,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _expiryDate = null),
                      ),
                helperText: l10n.expiryDateOptional,
              ),
              child: InkWell(
                onTap: _pickExpiryDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _expiryDate == null
                        ? ''
                        : DateFormat('d/M/yyyy', 'ar').format(_expiryDate!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
