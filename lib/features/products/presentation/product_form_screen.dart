import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../identity/identity.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// Product create/edit form (plan 05). Expiry date is truly optional —
/// no validation forces it. Cost and sell prices are required and must be
/// positive: a sale of a product with no cost would silently misstate
/// profit, so it is blocked here, never allowed (PLANS/05 edge cases).
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
    _expiryDate = product?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _sellController.dispose();
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
      await repository.create(
        pharmacyId: pharmacyId,
        name: name,
        costMinor: costMinor,
        sellMinor: sellMinor,
        expiryDate: _expiryDate,
      );
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
