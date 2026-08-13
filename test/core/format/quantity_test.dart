import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/format/quantity.dart';

/// Quantity formatting follows the money convention: pinned `ar_EG`
/// (Arabic-Indic digits in every context, not just inside localization
/// delegates), integers only — no minor units, no fractions (PLANS/12 D4).
void main() {
  test('formats positive integers in Arabic-Indic digits', () {
    expect(formatQuantity(0), '٠');
    expect(formatQuantity(25), '٢٥');
    expect(formatQuantity(1234), '١٬٢٣٤');
  });

  test('formats negative quantities with the locale minus sign (D3)', () {
    // intl's ar_EG includes the Arabic Letter Mark (U+061C) before the
    // minus — the correct RTL rendering, pinned here as reality.
    expect(formatQuantity(-3), '؜-٣');
    expect(formatQuantity(-12), '؜-١٢');
  });
}