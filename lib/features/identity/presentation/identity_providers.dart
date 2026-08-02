import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../data/identity_repository_impl.dart';
import '../domain/identity_repository.dart';
import '../domain/user_profile.dart';

/// drift-backed identity repository, wired via DI providers.
final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return DriftIdentityRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secureStoreProvider),
  );
});

/// The currently active profile — the attribution source every later
/// feature reads ("who logged this sale/draw"), resolved via the public
/// `identity.dart` barrel only.
final activeProfileProvider =
    AsyncNotifierProvider<ActiveProfileNotifier, UserProfile?>(
      ActiveProfileNotifier.new,
    );

class ActiveProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() {
    return ref.read(identityRepositoryProvider).getLastActiveProfile();
  }

  /// Switches the active profile and remembers it for next launch.
  /// The PIN gate (if any) is enforced by the caller before invoking.
  Future<void> switchTo(UserProfile profile) async {
    final repository = ref.read(identityRepositoryProvider);
    await repository.setLastActiveProfile(profile);
    state = AsyncValue.data(profile);
  }

  /// Used after local-identity wipe (PIN reset path): back to no profile.
  Future<void> reset() async {
    state = const AsyncValue.data(null);
  }
}

/// All profiles on this device, for the switcher screen.
final profileListProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) {
  return ref.read(identityRepositoryProvider).getProfiles();
});
