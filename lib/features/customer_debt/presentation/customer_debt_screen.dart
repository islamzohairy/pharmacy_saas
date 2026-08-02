import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../identity/identity.dart';
import '../../ledger/ledger.dart';
import 'customer_debt_providers.dart';

/// Customer debt tracking (plan 06): live balance per customer, plus
/// debt-entry and repayment flows through plan 04's use-cases. Parties are
/// never deleted in P0 — destructive deletion is blocked by design
/// (DECISIONS.md: no delete path, FK RESTRICT at the database layer).
class CustomerDebtScreen extends ConsumerWidget {
  const CustomerDebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final balancesAsync = ref.watch(customerListWithBalancesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.customerDebtTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addCustomer,
        onPressed: () => _createCustomer(context, ref),
        child: const Icon(Icons.add),
      ),
      body: balancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CustomerDebtError(
          onRetry: () => ref.invalidate(customerListWithBalancesProvider),
        ),
        data: (balances) => balances.isEmpty
            ? _CustomerDebtEmpty(onAdd: () => _createCustomer(context, ref))
            : ListView.builder(
                itemCount: balances.length,
                itemBuilder: (context, index) =>
                    _CustomerTile(balance: balances[index]),
              ),
      ),
    );
  }

  Future<void> _createCustomer(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = await _CustomerNameDialog.show(
      context,
      title: l10n.addCustomer,
    );
    if (name == null) return;

    final profile = await ref.read(activeProfileProvider.future);
    final pharmacyId = profile?.pharmacyId;
    if (pharmacyId == null) return;

    await ref
        .read(customerRepositoryProvider)
        .create(pharmacyId: pharmacyId, name: name);
  }
}

class _CustomerTile extends ConsumerWidget {
  const _CustomerTile({required this.balance});

  final CustomerBalance balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final owed = balance.owedMinor;
    final balanceText = owed < 0
        ? '${l10n.creditBalance} ${formatEgp(-owed)}'
        : formatEgp(owed);
    return ListTile(
      title: Text(balance.customer.name),
      subtitle: Text(balanceText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.recordCustomerDebt,
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => _recordDebt(context, ref),
          ),
          IconButton(
            tooltip: l10n.recordRepayment,
            icon: const Icon(Icons.currency_exchange),
            onPressed: () => _recordRepayment(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _recordDebt(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final input = await _DebtEntryDialog.show(
      context,
      title: l10n.recordDebtTitle,
    );
    if (input == null) return;

    final profile = await ref.read(activeProfileProvider.future);
    final pharmacyId = profile?.pharmacyId;
    if (pharmacyId == null) return;

    try {
      await recordCustomerDebt(
        ref.read(ledgerRepositoryProvider),
        pharmacyId: pharmacyId,
        customerId: balance.customer.id,
        amountMinor: input.amountMinor,
        profileId: profile?.id,
        note: input.note,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.debtRecorded)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.recordFailed)));
    }
  }

  Future<void> _recordRepayment(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final input = await _DebtEntryDialog.show(
      context,
      title: l10n.recordRepaymentTitle,
    );
    if (input == null) return;

    final profile = await ref.read(activeProfileProvider.future);
    final pharmacyId = profile?.pharmacyId;
    if (pharmacyId == null) return;

    try {
      await recordRepayment(
        ref.read(ledgerRepositoryProvider),
        pharmacyId: pharmacyId,
        amountMinor: input.amountMinor,
        customerId: balance.customer.id,
        profileId: profile?.id,
        note: input.note,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.repaymentRecorded)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.recordFailed)));
    }
  }
}

/// Name-only creation dialog, mirroring the supplier screen's (each feature
/// owns its copy — no forced shared abstraction).
class _CustomerNameDialog extends StatelessWidget {
  const _CustomerNameDialog._({required this.title});

  final String title;

  /// Shows the dialog and resolves with the trimmed name, or null if
  /// dismissed.
  static Future<String?> show(BuildContext context, {required String title}) {
    return showDialog<String>(
      context: context,
      builder: (context) => _CustomerNameDialog._(title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = TextEditingController();
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.customerNameLabel),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          final name = controller.text.trim();
          if (name.isNotEmpty) Navigator.of(context).pop(name);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) Navigator.of(context).pop(name);
          },
          child: Text(l10n.confirmAdd),
        ),
      ],
    );
  }
}

/// Amount + optional note dialog used for both debt entries and
/// repayments, mirroring the supplier screen's. Validates through the same
/// money rules as every other money input in the app ([parseEgpToMinor],
/// positive amount).
class _DebtEntryDialog extends StatefulWidget {
  const _DebtEntryDialog._({required this.title});

  final String title;

  /// Shows the dialog and resolves with the parsed input, or null if
  /// dismissed.
  static Future<_DebtEntryInput?> show(
    BuildContext context, {
    required String title,
  }) {
    return showDialog<_DebtEntryInput>(
      context: context,
      builder: (context) => _DebtEntryDialog._(title: title),
    );
  }

  @override
  State<_DebtEntryDialog> createState() => _DebtEntryDialogState();
}

class _DebtEntryDialogState extends State<_DebtEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

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

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      _DebtEntryInput(
        amountMinor: parseEgpToMinor(_amountController.text.trim()),
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: l10n.debtAmountLabel,
                helperText: l10n.priceHelper,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              validator: _amountValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(labelText: l10n.noteOptionalLabel),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _confirm, child: Text(l10n.save)),
      ],
    );
  }
}

class _DebtEntryInput {
  const _DebtEntryInput({required this.amountMinor, this.note});

  final int amountMinor;
  final String? note;
}

class _CustomerDebtEmpty extends StatelessWidget {
  const _CustomerDebtEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.customersEmpty,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.customersEmptyHint,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addCustomer),
          ),
        ],
      ),
    );
  }
}

class _CustomerDebtError extends StatelessWidget {
  const _CustomerDebtError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.loadError, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
