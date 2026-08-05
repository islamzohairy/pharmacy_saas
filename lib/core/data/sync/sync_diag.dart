/// Compile-time-gated sync diagnostics (SYNC_DIAG=true rebuilds).
///
/// Default off in every release. Content rule (DECISIONS.md 2026-08-05):
/// lines carry states, counts, timestamps and error codes only — never
/// ledger amounts, notes, tokens, or profile names.
const kSyncDiag = bool.fromEnvironment('SYNC_DIAG', defaultValue: false);

/// Prints a `[SYNC_DIAG]` line when the build has SYNC_DIAG=true.
///
/// `print` (not `developer.log`): the latter was observed invisible in
/// logcat and the flutter-run console in this environment, while prints
/// are visible — the deep support channel for pilot diagnostics.
void syncDiag(String message) {
  // ignore: avoid_print
  if (kSyncDiag) print('[SYNC_DIAG] $message');
}
