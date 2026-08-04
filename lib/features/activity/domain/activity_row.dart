import '../../ledger/ledger.dart';

/// One row of the activity feed: a [LedgerEntry] joined with the display
/// name of the profile that recorded it (when attribution exists).
///
/// Deliberately small — the entry carries the financial facts; the resolved
/// name is what the screen needs to answer "who did this." Localized label
/// selection is a presentation concern (l10n keys by type/category), so it
/// stays out of this helper.
class ActivityRow {
  const ActivityRow({required this.entry, this.actorDisplayName});

  final LedgerEntry entry;
  final String? actorDisplayName;

  /// Maps a raw ledger entry into a display row, resolving the recorder's
  /// name from [profileNames] (profileId → displayName); null when the
  /// entry has no attribution or the profile is unknown.
  factory ActivityRow.fromEntry(
    LedgerEntry entry,
    Map<int, String> profileNames,
  ) {
    final profileId = entry.profileId;
    return ActivityRow(
      entry: entry,
      actorDisplayName: profileId == null
          ? null
          : profileNames[profileId],
    );
  }
}
