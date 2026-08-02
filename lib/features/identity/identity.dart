/// Public API of the identity feature.
///
/// Other features import this barrel only — never this feature's
/// internals (no-cross-feature-internal-imports rule, GLOBAL_RULES.md).
library;

export 'domain/identity_repository.dart';
export 'domain/pharmacy.dart';
export 'domain/user_profile.dart';
export 'domain/user_role.dart';
export 'presentation/identity_providers.dart'
    show
        ActiveProfileNotifier,
        activeProfileProvider,
        identityRepositoryProvider,
        profileListProvider;
