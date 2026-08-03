/// Public API of the dashboard feature.
///
/// Other features import this barrel only — never this feature's
/// internals (no-cross-feature-internal-imports rule, GLOBAL_RULES.md).
library;

export 'domain/dashboard_range.dart';
export 'presentation/dashboard_providers.dart';
