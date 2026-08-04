import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/error_log_providers.dart';
import '../l10n/app_l10n.dart';

/// Crash/error visibility for the pilot owner (PLANS/09) — sits beside
/// [BackupStatusIndicator] so an unhandled error becomes *seen* even though
/// the pilot has no in-app support channel.
///
/// Hidden entirely while the unreported count is zero. Tapping opens a
/// dialog that exports the entries as plain text (clipboard — no new
/// dependency, no privacy surface, offline) and offers the explicit
/// "reported/dismissed" action. The count is cleared ONLY by that action —
/// opening the dashboard never swallows a crash.
class ErrorLogIndicator extends ConsumerWidget {
  const ErrorLogIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // `valueOrNull` (not `.value`): an error-state provider would make
    // `.value` rethrow, and the log is a best-effort surface that must never
    // take the screen down (e.g. tests that render the dashboard without a
    // database). `hasValue`/`valueOrNull` keeps it a quiet no-op instead.
    final count = ref.watch(unreportedErrorCountProvider).valueOrNull ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showExportDialog(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bug_report_outlined, size: 16),
            const SizedBox(width: 4),
            Text(
              '${l10n.errorLogUnreported} ($count)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final repository = ref.read(errorLogRepositoryProvider);
    final entries = await repository.unreportedEntries();
    if (!context.mounted) return;

    final report = _buildReport(l10n, entries);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.errorLogDialogTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: entries.isEmpty
              ? Text(l10n.errorLogNoEntries)
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline, size: 20),
                      title: Text(entry.errorType),
                      subtitle: Text(
                        entry.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: false,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: entries.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: report));
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.errorLogCopiedSnackbar)),
                    );
                  },
            child: Text(l10n.errorLogExportReport),
          ),
          TextButton(
            onPressed: () async {
              await repository.markAllReported();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.errorLogReportedDismiss),
          ),
        ],
      ),
    );
  }

  /// The plain-text artifact the pilot hands to support: header, entry
  /// count, then per entry — timestamp, type, message, truncated stack.
  String _buildReport(AppLocalizations l10n, List<StoredErrorLogEntry> entries) {
    final dateFormat = DateFormat('d/M/yyyy HH:mm');
    final buffer = StringBuffer()
      ..writeln(l10n.errorLogReportHeader)
      ..writeln('${l10n.errorLogUnreported}: ${entries.length}')
      ..writeln('----');
    for (final entry in entries) {
      buffer
        ..writeln(
          '[${dateFormat.format(entry.occurredAt)}] ${entry.errorType}',
        )
        ..writeln(entry.message);
      final stack = entry.stackTrace;
      if (stack != null && stack.isNotEmpty) {
        buffer.writeln(stack.split('\n').take(8).join('\n'));
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}