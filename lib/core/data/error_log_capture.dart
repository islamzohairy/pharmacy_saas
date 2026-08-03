import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'error_log_repository.dart';

/// The shared sink for every error handler, set once at startup after the
/// database opens (null = too early in startup — writes are dropped
/// silently rather than buffered).
ErrorLogRepository? _repository;

/// Installs the crash-visibility capture layers (PLANS/09). Call once from
/// `main()` right after the database is opened, before the first frame:
///
/// 1. [reportZoneErrors] — the `runZonedGuarded` handler in `main`, for
///    async/zone escapes.
/// 2. `FlutterError.onError` — framework errors; the previous handler is
///    chained (preserving MCPToolkit's debug forwarding), not replaced.
/// 3. `PlatformDispatcher.instance.onError` — engine errors that escape the
///    zone; the prior handler is called first and its result returned, so
///    existing crash semantics are unchanged.
///
/// Every write is fire-and-forget with failures swallowed: a logging bug
/// must never itself take the app down.
void installErrorLogCapture(AppDatabase database) {
  _repository = ErrorLogRepository(database);

  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutterError?.call(details);
    _record(details.exception, details.stack);
  };

  final previousDispatcherError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    final previouslyHandled =
        previousDispatcherError?.call(error, stack) ?? false;
    _record(error, stack);
    return previouslyHandled;
  };
}

/// The `runZonedGuarded` callback for `main` (PLANS/09 layer 1).
void reportZoneErrors(Object error, StackTrace stack) {
  _record(error, stack);
}

void _record(Object error, StackTrace? stack) {
  final repository = _repository;
  if (repository == null) return;
  unawaited(
    repository
        .record(
          errorType: error.runtimeType.toString(),
          message: error.toString(),
          stackTrace: stack?.toString(),
        )
        .catchError((Object _) {}),
  );
}
