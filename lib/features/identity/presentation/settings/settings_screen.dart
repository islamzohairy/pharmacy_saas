import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../identity_providers.dart';

/// Compliance-prep settings (PLANS/10 Phase 4): captures the pharmacy's
/// tax registration number and legal business name for a future
/// e-invoicing/ETA flow. Both fields optional, inert data — explicitly not
/// a compliance feature (COMPLIANCE.md).
///
/// The first update-after-onboarding path for the pharmacy entity; the
/// write goes through `IdentityRepository.updatePharmacySettings`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taxController = TextEditingController();
  final _legalNameController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  /// Basic length cap only — the fields are optional and inert.
  static const _maxLength = 100;

  @override
  void dispose() {
    _taxController.dispose();
    _legalNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loaded) return;
    final pharmacy = await ref.read(identityRepositoryProvider).getPharmacy();
    if (!mounted) return;
    _taxController.text = pharmacy.taxRegistrationNumber ?? '';
    _legalNameController.text = pharmacy.legalBusinessName ?? '';
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(identityRepositoryProvider).updatePharmacySettings(
        taxRegistrationNumber: _taxController.text.trim().isEmpty
            ? null
            : _taxController.text.trim(),
        legalBusinessName: _legalNameController.text.trim().isEmpty
            ? null
            : _legalNameController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.settingsSaved)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.settingsSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    _load();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.settingsComplianceSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsComplianceNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taxController,
              decoration: InputDecoration(
                labelText: l10n.settingsTaxRegistrationLabel,
              ),
              maxLength: _maxLength,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _legalNameController,
              decoration: InputDecoration(
                labelText: l10n.settingsLegalBusinessNameLabel,
              ),
              maxLength: _maxLength,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.settingsSave),
            ),
          ],
        ),
      ),
    );
  }
}