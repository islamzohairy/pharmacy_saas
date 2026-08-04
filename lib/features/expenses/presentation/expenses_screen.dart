import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../identity/identity.dart';
import '../../ledger/ledger.dart';
import 'expenses_providers.dart';

/// Expense logging (PLANS/10 Phase 2, replacing the standalone Draws
/// screen): pick a category (Owner Draw is the default/first option — the
/// fast-logging property of the old draw screen must not regress) + amount
/// + optional note → exactly one append-only `expense` ledger row with its
/// category, attributed to the active profile. Shows the recent expenses
/// beneath the form.
///
/// Stays on this screen after a successful save (fields cleared) so a
/// sequence of expenses is a handful of taps.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.ownerDraw;
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
      await recordExpense(
        ref.read(ledgerRepositoryProvider),
        pharmacyId: pharmacyId,
        category: _category,
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
        ..showSnackBar(SnackBar(content: Text(l10n.expenseRecorded)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.expensesTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.expenseCategoryLabel),
              items: [
                for (final category in ExpenseCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(_categoryLabel(l10n, category)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: l10n.expenseAmountLabel,
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
              child: Text(l10n.recordExpense),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.expensesHistoryTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const _ExpenseHistory(),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, ExpenseCategory category) {
    return switch (category) {
      ExpenseCategory.ownerDraw => l10n.expenseCategoryOwnerDraw,
      ExpenseCategory.rent => l10n.expenseCategoryRent,
      ExpenseCategory.utilities => l10n.expenseCategoryUtilities,
      ExpenseCategory.supplies => l10n.expenseCategorySupplies,
      ExpenseCategory.other => l10n.expenseCategoryOther,
    };
  }
}

/// The recent-expenses section: newest first, each row showing category,
/// amount, date and (when present) the note.
class _ExpenseHistory extends ConsumerWidget {
  const _ExpenseHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(expenseEntriesProvider);

    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.loadError, textAlign: TextAlign.center),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.expensesHistoryEmpty,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          children: [
            for (final entry in entries)
              ListTile(
                dense: true,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(_categoryLabel(l10n, entry.category)),
                subtitle: entry.note == null
                    ? null
                    : Text(entry.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(
                  formatEgp(entry.amountMinor),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        );
      },
    );
  }

  String _categoryLabel(AppLocalizations l10n, ExpenseCategory? category) {
    return switch (category) {
      ExpenseCategory.ownerDraw => l10n.expenseCategoryOwnerDraw,
      ExpenseCategory.rent => l10n.expenseCategoryRent,
      ExpenseCategory.utilities => l10n.expenseCategoryUtilities,
      ExpenseCategory.supplies => l10n.expenseCategorySupplies,
      ExpenseCategory.other => l10n.expenseCategoryOther,
      // Shouldn't happen (category is required on expense rows) but render
      // something rather than crash the history list.
      null => l10n.expenseCategoryOther,
    };
  }
}