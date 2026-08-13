import 'package:intl/intl.dart';

/// EGP money formatting/parsing for the UI layer (P0 is EGP-only).
///
/// Money itself is always integer minor units (piastres) — this file only
/// converts between that canonical form and what the user sees/types.
/// Formatting uses the `ar_EG` locale (Arabic-Indic digits, locale
/// grouping) — pinned explicitly because plain `ar` falls back to Latin
/// digits unless app localization delegates happen to have initialized it;
/// `ar_EG` resolves to the same Arabic-Indic symbols in every context
/// (app, widget tests, bare Dart). Call `initializeDateFormatting('ar')`
/// once before first use in a non-widget context.
final NumberFormat _egpNumberFormat = NumberFormat('#,##0.00', 'ar_EG');

/// Formats minor units as an EGP display string, e.g. `2550` → `٢٥٫٥٠ ج.م`.
String formatEgp(int minorUnits) {
  return '${_egpNumberFormat.format(minorUnits / 100)} ج.م';
}

final RegExp _egpPattern = RegExp(r'^\d+(\.\d{1,2})?$');
const String _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Maps Arabic-Indic digits (`٠١٢٣٤٥٦٧٨٩`) to their Western equivalents,
/// leaving every other character untouched. Shared by [parseEgpToMinor]
/// and the inventory quantity parsing path (PLANS/12) so both accept
/// Arabic-Indic keyboard input through one convention — no second parsing
/// path with its own digit handling.
///
/// Behavior-preserving by contract: extracting this helper must not
/// change [parseEgpToMinor]'s behavior — the existing money tests are
/// the proof.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final digit = _arabicDigits.indexOf(String.fromCharCode(rune));
    buffer.write(digit >= 0 ? '$digit' : String.fromCharCode(rune));
  }
  return buffer.toString();
}

/// Parses a user-typed EGP amount into piastres.
///
/// Accepts Western or Arabic-Indic digits, an optional single decimal
/// separator (`.` or `٫`) and optional thousands separators (`,`/`٬`);
/// anything else (letters, signs, 3+ decimals, empty) throws
/// [FormatException]. `"25.5"` and `"٢٥٫٥٠"` both yield `2550`.
int parseEgpToMinor(String input) {
  var normalized = input
      .replaceAll(RegExp(r'[\s\u00A0\u200F\u200E]'), '')
      .replaceAll('٫', '.')
      .replaceAll(',', '')
      .replaceAll('٬', '');
  normalized = normalizeDigits(normalized);

  if (!_egpPattern.hasMatch(normalized)) {
    throw FormatException('invalid EGP amount: $input');
  }
  final parts = normalized.split('.');
  final whole = int.parse(parts[0]);
  final fraction = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return whole * 100 + fraction;
}
