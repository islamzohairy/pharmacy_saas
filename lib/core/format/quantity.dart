import 'package:intl/intl.dart';

/// Quantity formatting for the UI layer (PLANS/12 D4 — plain integer
/// units, no fractions).
///
/// Pinned to `ar_EG` for the same reason the money formatter is: plain
/// `ar` falls back to Latin digits unless app localization delegates have
/// initialized it; `ar_EG` resolves to Arabic-Indic symbols in every
/// context. Negatives format with the locale's minus sign and Arabic-
/// Indic digits (e.g. `-3` → `-٣`), matching the never-clamp display
/// rule (D3).
final NumberFormat _quantityFormat = NumberFormat('#,##0', 'ar_EG');

/// Formats an integer quantity for display, e.g. `25` → `٢٥`, `-3` → `-٣`.
String formatQuantity(int quantity) => _quantityFormat.format(quantity);
