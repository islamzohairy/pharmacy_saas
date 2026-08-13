import '../data/tables/expense_category.dart';
import 'app_l10n.dart';

/// Display label for an expense category — the single shared mapping.
///
/// Previously duplicated per screen (expenses, activity, and then the
/// dashboard's Plan 14 insight would have made it a third copy);
/// extracted to core so every consumer renders identical labels
/// (CODE_REVIEW_RULES: no duplicated logic that should be a shared
/// function). Pure presentation mapping, no state.
String expenseCategoryLabel(AppLocalizations l10n, ExpenseCategory category) {
  return switch (category) {
    ExpenseCategory.ownerDraw => l10n.expenseCategoryOwnerDraw,
    ExpenseCategory.rent => l10n.expenseCategoryRent,
    ExpenseCategory.utilities => l10n.expenseCategoryUtilities,
    ExpenseCategory.supplies => l10n.expenseCategorySupplies,
    ExpenseCategory.other => l10n.expenseCategoryOther,
  };
}