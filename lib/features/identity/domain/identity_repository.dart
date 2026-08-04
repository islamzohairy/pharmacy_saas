import 'pharmacy.dart';
import 'user_profile.dart';

/// Identity operations for the device-local profile system.
///
/// Domain code depends on this interface only — the drift-backed
/// implementation stays in `data/` (repository pattern, ARCHITECTURE.md).
abstract interface class IdentityRepository {
  /// True when at least one profile exists (i.e. onboarding is complete).
  Future<bool> hasAnyProfile();

  /// Creates the pharmacy and its owner profile atomically.
  /// No network call — this is a local, device-level identity.
  Future<({Pharmacy pharmacy, UserProfile owner})> createPharmacyAndOwner({
    required String pharmacyName,
    required String currency,
    required String ownerDisplayName,
  });

  Future<Pharmacy> getPharmacy();

  /// Updates the compliance-prep fields on the pharmacy — the first
  /// update-after-onboarding path for this entity (everything else is
  /// create-once). Both fields optional and inert (PLANS/10 Phase 4);
  /// missing fields keep their current value.
  Future<Pharmacy> updatePharmacySettings({
    required String? taxRegistrationNumber,
    required String? legalBusinessName,
  });

  /// The device's secret backup token: a random 256-bit value generated
  /// at onboarding, persisted in secure storage (never in the drift DB).
  /// Authenticates this install to the remote backup path — see
  /// SECURITY.md and DECISIONS.md.
  Future<String> getDeviceToken();

  /// Whether this device has already registered its token against the
  /// remote backup backend (register-first-wins, done at first sync).
  Future<bool> isDeviceRegistered();

  /// Records that registration succeeded. Only meaningful for the backup
  /// path; the flag lives in secure storage with the token.
  Future<void> markDeviceRegistered();

  Future<List<UserProfile>> getProfiles();

  /// Adds a `family`-role profile for the shared-shift pattern.
  Future<UserProfile> addFamilyProfile({required String displayName});

  Future<UserProfile?> getProfile(int id);

  /// Stores a salted hash of [pin] in secure storage, never the PIN.
  Future<void> setPin(UserProfile profile, String pin);

  /// Returns true when [pin] matches the profile's stored hash.
  Future<bool> verifyPin(UserProfile profile, String pin);

  Future<void> clearPin(UserProfile profile);

  /// Last active profile, remembered so the app doesn't force a choice
  /// on every launch.
  Future<UserProfile?> getLastActiveProfile();

  Future<void> setLastActiveProfile(UserProfile profile);

  /// PIN-reset path: there is no server-side recovery in P0, so resetting
  /// means wiping local identity and re-onboarding. Caller must confirm.
  Future<void> wipeLocalIdentity();
}
