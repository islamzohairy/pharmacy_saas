import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_l10n.dart';
import '../theme/app_theme.dart';

/// The non-destructive fatal-error surface for a failed database open
/// (PLANS/11 §4.3).
///
/// Shown ONLY when [openAppDatabase] throws — corrupt file, lost encryption
/// key, failing migration. The database file is never deleted or recreated
/// by the open path, so this screen's only jobs are: reassure (data is
/// intact), export a minimal plain-text report (no ledger content — the DB
/// isn't reachable, so none could leak), and retry on the user's explicit
/// tap. No automatic retry loops.
class DatabaseFatalErrorApp extends StatelessWidget {
  const DatabaseFatalErrorApp({
    super.key,
    required this.report,
    required this.retry,
  });

  /// The plain-text report copied to the clipboard (timestamp + error,
  /// no data content).
  final String report;

  /// User-triggered retry: re-attempts the database open and swaps in the
  /// real app on success. Must complete (success or failure) — failures
  /// are surfaced by the screen.
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DatabaseFatalErrorScreen(report: report, retry: retry),
    );
  }
}

class DatabaseFatalErrorScreen extends StatefulWidget {
  const DatabaseFatalErrorScreen({
    super.key,
    required this.report,
    required this.retry,
  });

  final String report;
  final Future<void> Function() retry;

  @override
  State<DatabaseFatalErrorScreen> createState() =>
      _DatabaseFatalErrorScreenState();
}

class _DatabaseFatalErrorScreenState extends State<DatabaseFatalErrorScreen> {
  bool _retrying = false;

  Future<void> _copyReport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.fatalDatabaseReportCopied)),
    );
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.retry();
    } catch (_) {
      if (!mounted) return;
      setState(() => _retrying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.fatalDatabaseRetryFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.storage,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.fatalDatabaseTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.fatalDatabaseBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _retrying
                          ? null
                          : () => _copyReport(context),
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.fatalDatabaseCopyReport),
                    ),
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
