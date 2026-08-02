import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../identity/identity.dart';
import '../../ledger/ledger.dart';

/// Cash draw logging (plan 06): amount + optional note → exactly one
/// append-only `cashDraw` ledger row through plan 04's [recordDraw]
/// use-case, attributed to the active profile.
///
/// Stays on this screen after a successful save (fields cleared) so a
/// sequence of draws is a handful of taps — the owner logs cash taken out
/// as it happens, not in a batch later.
class DrawsScreen extends ConsumerStatefulWidget {
  const DrawsScreen({super.key});

  @override
  ConsumerState<DrawsScreen> createState() => _DrawsScreenState();
}

class _DrawsScreenState extends ConsumerState<DrawsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _amountValidator(String? value) {
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

  Future<void> _record() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = context.l10n;
    final profile = await ref.read(activeProfileProvider.future);
    final pharmacyId = profile?.pharmacyId;
    if (pharmacyId == null) return;

    setState(() => _saving = true);
    final note = _noteController.text.trim();
    try {
      await recordDraw(
        ref.read(ledgerRepositoryProvider),
        pharmacyId: pharmacyId,
        amountMinor: parseEgpToMinor(_amountController.text.trim()),
        profileId: profile?.id,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _amountController.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.drawRecorded)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.drawFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.drawsTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: l10n.drawAmountLabel,
                helperText: l10n.priceHelper,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _amountValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(labelText: l10n.noteOptionalLabel),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _record,
              child: Text(l10n.recordDraw),
            ),
          ],
        ),
      ),
    );
  }
}
