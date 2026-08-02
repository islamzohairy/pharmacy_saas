import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/sync/sync_providers.dart';
import 'core/l10n/app_l10n.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';

/// Root widget. Arabic-primary, RTL — locale pinned to `ar` for P0.
///
/// Also owns the app-lifecycle observer: every foreground resume triggers
/// an immediate backup pass (plan 03 — "on app foreground + connectivity").
class PharmacyApp extends ConsumerStatefulWidget {
  const PharmacyApp({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends ConsumerState<PharmacyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncSchedulerProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: widget.router,
    );
  }
}
