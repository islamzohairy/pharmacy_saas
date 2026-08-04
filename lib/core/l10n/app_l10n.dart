import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart' show AppLocalizations;

/// Typed access to the app's localizations.
///
/// `AppLocalizations.of` is nullable by contract but the locale is pinned
/// to `ar` and the delegates are always installed, so lookup never fails —
/// the `!` is safe here and centralized instead of scattered per screen.
extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
