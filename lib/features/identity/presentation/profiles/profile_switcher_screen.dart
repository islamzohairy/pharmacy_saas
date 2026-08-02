import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/router/app_router.dart';
import '../../identity.dart';
import 'pin_entry_dialog.dart';
import 'pin_setup_dialog.dart';

/// Lightweight profile switcher — not a login screen. Adds a family
/// profile for the shared-shift pattern and switches the active profile,
/// gated by the profile's PIN when one is set.
class ProfileSwitcherScreen extends ConsumerWidget {
  const ProfileSwitcherScreen({super.key});

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.forgotPinTitle),
        content: Text(l10n.forgotPinBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirmReset),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(identityRepositoryProvider).wipeLocalIdentity();
    await ref.read(activeProfileProvider.notifier).reset();
    if (context.mounted) context.goNamed(AppRoutes.onboarding);
  }

  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final repository = ref.read(identityRepositoryProvider);

    if (profile.hasPin) {
      final result = await showPinEntryDialog(
        context,
        onVerify: (pin) => repository.verifyPin(profile, pin),
      );
      if (result == PinEntryResult.forgot) {
        if (!context.mounted) return;
        await _confirmWipe(context, ref);
        return;
      }
      if (result != PinEntryResult.verified) return;
    }

    await ref.read(activeProfileProvider.notifier).switchTo(profile);
    if (context.mounted) context.goNamed(AppRoutes.dashboard);
  }

  Future<void> _addFamilyProfile(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddFamilyProfileDialog(),
    );

    if (name == null || !context.mounted) return;
    await ref.read(identityRepositoryProvider).addFamilyProfile(
      displayName: name,
    );
    ref.invalidate(profileListProvider);
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final repository = ref.read(identityRepositoryProvider);
    final l10n = context.l10n;

    if (profile.hasPin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.clearPin),
          content: Text(profile.displayName),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.clearPin),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await repository.clearPin(profile);
      }
    } else {
      final pin = await showPinSetupDialog(context);
      if (pin != null) {
        await repository.setPin(profile, pin);
      }
    }
    if (context.mounted) ref.invalidate(profileListProvider);
  }

  String _roleLabel(BuildContext context, UserRole role) {
    final l10n = context.l10n;
    return switch (role) {
      UserRole.owner => l10n.roleOwner,
      UserRole.family => l10n.roleFamily,
      UserRole.employee => l10n.roleEmployee,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profilesAsync = ref.watch(profileListProvider);
    final activeAsync = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profilesTitle),
        actions: [
          IconButton(
            tooltip: l10n.addProfileTooltip,
            icon: const Icon(Icons.person_add),
            onPressed: () => _addFamilyProfile(context, ref),
          ),
        ],
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (profiles) {
          final active = activeAsync.valueOrNull;
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.onboardingTitle),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.goNamed(AppRoutes.onboarding),
                    child: Text(l10n.createAndStart),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isActive = profile.id == active?.id;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(profile.displayName),
                subtitle: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_roleLabel(context, profile.role)),
                    if (profile.hasPin) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.lock, size: 14),
                    ],
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Text(
                        l10n.currentProfileBadge,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  tooltip: profile.hasPin ? l10n.clearPin : l10n.setPin,
                  icon: Icon(
                    profile.hasPin ? Icons.lock_open : Icons.lock_outline,
                  ),
                  onPressed: () => _togglePin(context, ref, profile),
                ),
                onTap: () => _switchTo(context, ref, profile),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dialog that owns its own [TextEditingController] so disposal follows
/// the widget lifecycle, not the closing dialog's exit animation.
class _AddFamilyProfileDialog extends StatefulWidget {
  const _AddFamilyProfileDialog();

  @override
  State<_AddFamilyProfileDialog> createState() =>
      _AddFamilyProfileDialogState();
}

class _AddFamilyProfileDialogState extends State<_AddFamilyProfileDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_nameController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addFamilyProfile),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.familyProfileNameLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? l10n.familyProfileNameRequired
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.addProfile)),
      ],
    );
  }
}
