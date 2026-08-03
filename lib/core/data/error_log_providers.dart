import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_providers.dart';
import 'error_log_repository.dart';

/// The local error-log store. Backed by drift like every other repository.
final errorLogRepositoryProvider = Provider<ErrorLogRepository>(
  (ref) => ErrorLogRepository(ref.watch(appDatabaseProvider)),
);

/// Live unreported count for the dashboard indicator (PLANS/09). Hidden
/// entirely at zero — a quiet app is the happy state.
final unreportedErrorCountProvider = StreamProvider<int>(
  (ref) => ref.watch(errorLogRepositoryProvider).watchUnreportedCount(),
);
