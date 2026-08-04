import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/tables/ledger_entry_type.dart';

/// Regression test for the Phase 0 wire-format bug (PLANS/10): `wireName`
/// once returned `name` — Dart's camelCase identifier (`cashDraw`,
/// `supplierDebt`, ...) — while the remote whitelist enforces snake_case
/// (`cash_draw`, `supplier_debt`, ...). Only `sale` matches either way,
/// which is why the bug survived ad hoc testing. After PLANS/10 Phase 1
/// the enum member is `expense` (which happens to match its wire form).
///
/// These literals are the server-side whitelist:
///   * CHECK constraint — supabase/migrations/0001_pharmacy_schema.sql
///     (the `type in (...)` list, and the same list inside
///     push_ledger_entries' validation)
///   * 0002_expense_category.sql keeps `cash_draw` (historical remote
///     rows) and adds `expense` to both lists — when that lands, the
///     enum switch and this map stay in sync through the compiler-plus-
///     test pair.
void main() {
  const remoteWhitelist = {
    LedgerEntryType.sale: 'sale',
    LedgerEntryType.expense: 'expense',
    LedgerEntryType.supplierDebt: 'supplier_debt',
    LedgerEntryType.customerDebt: 'customer_debt',
    LedgerEntryType.debtRepayment: 'debt_repayment',
  };

  test('every type wireName matches the remote whitelist', () {
    for (final type in LedgerEntryType.values) {
      expect(
        type.wireName,
        remoteWhitelist[type],
        reason: '${type.name} must serialize to the value '
            'push_ledger_entries accepts on the server; '
            'if you added a ledger type, add its wire name to both '
            'the enum switch and this whitelist map',
      );
    }
  });

  test('whitelist map covers every enum value (no silent additions)', () {
    expect(remoteWhitelist.keys.toSet(), LedgerEntryType.values.toSet());
  });
}
