import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/data/sync/sync_error_classification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  PostgrestException sqlstate(String code) =>
      PostgrestException(message: 'boom', code: code);

  test('the ruled permanent set {23514,23503,23502,22P02} → permanent', () {
    for (final code in ['23514', '23503', '23502', '22P02']) {
      expect(
        classifySyncError(sqlstate(code)),
        SyncFailureClass.permanent,
        reason: code,
      );
    }
  });

  test('23505 (unique violation) → alreadyExists', () {
    expect(classifySyncError(sqlstate('23505')), SyncFailureClass.alreadyExists);
  });

  test('everything else is transient: other SQLSTATEs, null code, '
      'non-Postgrest errors', () {
    expect(classifySyncError(sqlstate('401')), SyncFailureClass.transient);
    expect(classifySyncError(sqlstate('403')), SyncFailureClass.transient);
    expect(classifySyncError(sqlstate('42P01')), SyncFailureClass.transient);
    expect(classifySyncError(sqlstate('500')), SyncFailureClass.transient);
    expect(
      classifySyncError(const PostgrestException(message: 'no code')),
      SyncFailureClass.transient,
    );
    expect(
      classifySyncError(const SocketException('offline')),
      SyncFailureClass.transient,
    );
    expect(classifySyncError(StateError('x')), SyncFailureClass.transient);
  });
}
