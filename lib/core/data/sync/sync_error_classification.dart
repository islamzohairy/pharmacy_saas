import 'package:supabase_flutter/supabase_flutter.dart';

/// How a sync failure should be handled (PLANS/11-H Phase 2).
enum SyncFailureClass {
  /// The server permanently rejects the data (ruled SQLSTATE set) —
  /// quarantine the batch, never retry.
  permanent,

  /// The server already accepted the rows (unique violation on the
  /// idempotent `(pharmacy_id, id)` key) — treat as pushed.
  alreadyExists,

  /// Everything else — transient, existing capped backoff.
  transient,
}

/// The ruled permanent SQLSTATE codes (DECISIONS.md 2026-08-05). This set
/// is byte-for-byte as ruled; no expansion without a new ruling.
const _permanentCodes = {'23514', '23503', '23502', '22P02'};

/// Classifies a push failure. [PostgrestException]s carry the server's
/// SQLSTATE in [PostgrestException.code]; anything else is transient.
SyncFailureClass classifySyncError(Object error) {
  if (error is PostgrestException) {
    final code = error.code;
    if (code != null) {
      if (_permanentCodes.contains(code)) return SyncFailureClass.permanent;
      if (code == '23505') return SyncFailureClass.alreadyExists;
    }
  }
  return SyncFailureClass.transient;
}
