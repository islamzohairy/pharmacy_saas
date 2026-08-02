import 'user_role.dart';

/// Device-local user profile. Plain domain object — no persistence or
/// presentation knowledge.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.pharmacyId,
    required this.role,
    required this.displayName,
    this.pinHashRef,
  });

  final int id;
  final int pharmacyId;

  /// Captured, not enforced in P0.
  final UserRole role;
  final String displayName;

  /// Reference to the PIN hash key inside secure storage; `null` when no
  /// PIN is configured. The hash itself never lives in the database.
  final String? pinHashRef;

  bool get hasPin => pinHashRef != null;
}
