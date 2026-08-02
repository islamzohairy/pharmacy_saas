import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/app_l10n.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';

/// Root widget. Arabic-primary, RTL — locale pinned to `ar` for P0.
class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
