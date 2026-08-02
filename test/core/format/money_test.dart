import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pharmacy_saas/core/format/money.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('formatEgp', () {
    test('formats whole pounds with two-decimal Arabic display', () {
      expect(formatEgp(2550), '٢٥٫٥٠ ج.م');
    });

    test('formats zero', () {
      expect(formatEgp(0), '٠٫٠٠ ج.م');
    });

    test('groups thousands with the locale separator', () {
      expect(formatEgp(255000), '٢٬٥٥٠٫٠٠ ج.م');
      expect(formatEgp(999999), '٩٬٩٩٩٫٩٩ ج.م');
    });

    test('handles sub-pound values', () {
      expect(formatEgp(1), '٠٫٠١ ج.م');
    });
  });

  group('parseEgpToMinor', () {
    test('parses Western digits with a decimal point', () {
      expect(parseEgpToMinor('25.50'), 2550);
      expect(parseEgpToMinor('25.5'), 2550);
      expect(parseEgpToMinor('25'), 2500);
    });

    test('parses Arabic-Indic digits and the Arabic decimal separator', () {
      expect(parseEgpToMinor('٢٥٫٥٠'), 2550);
      expect(parseEgpToMinor('٢٥٫٥'), 2550);
      expect(parseEgpToMinor('٢٥'), 2500);
    });

    test('ignores thousands separators and whitespace', () {
      expect(parseEgpToMinor('1,000.00'), 100000);
      expect(parseEgpToMinor('١٬٠٠٠٫٠٠'), 100000);
      expect(parseEgpToMinor('  25.50 '), 2550);
    });

    test('rejects negative, signed and symbolic input', () {
      expect(() => parseEgpToMinor('-5'), throwsFormatException);
      expect(() => parseEgpToMinor('+5'), throwsFormatException);
      expect(() => parseEgpToMinor('٪5'), throwsFormatException);
    });

    test('rejects more than two decimals and empty input', () {
      expect(() => parseEgpToMinor('25.500'), throwsFormatException);
      expect(() => parseEgpToMinor(''), throwsFormatException);
      expect(() => parseEgpToMinor('   '), throwsFormatException);
    });
  });

  test('parseEgpToMinor and formatEgp round-trip', () {
    expect(formatEgp(parseEgpToMinor('٢٥٫٥٠')), '٢٥٫٥٠ ج.م');
  });
}
