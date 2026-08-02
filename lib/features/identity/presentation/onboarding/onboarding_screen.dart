import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/router/app_router.dart';
import '../../identity.dart';

/// First-launch profile creation. Creates the pharmacy + owner profile
/// locally — no network call, no backend account (ARCHITECTURE.md
/// §Identity).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pharmacyNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _pharmacyNameController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final repository = ref.read(identityRepositoryProvider);
    final created = await repository.createPharmacyAndOwner(
      pharmacyName: _pharmacyNameController.text,
      currency: 'EGP',
      ownerDisplayName: _ownerNameController.text,
    );
    await repository.setLastActiveProfile(created.owner);
    await ref.read(activeProfileProvider.notifier).switchTo(created.owner);

    if (!mounted) return;
    context.goNamed(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _pharmacyNameController,
                      decoration: InputDecoration(
                        labelText: l10n.pharmacyNameLabel,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.pharmacyNameRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: InputDecoration(
                        labelText: l10n.ownerDisplayNameLabel,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.ownerDisplayNameRequired
                          : null,
                      onFieldSubmitted: (_) => _submitting ? null : _submit(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.currencyIsEgp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.createAndStart),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
