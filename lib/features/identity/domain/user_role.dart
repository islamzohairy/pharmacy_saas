/// Device-local user role.
///
/// Captured at profile creation but **not enforced anywhere in P0** —
/// an `employee` profile has identical access to `owner` today
/// (ARCHITECTURE.md §Identity, DECISIONS.md). UI must not imply otherwise.
enum UserRole {
  owner('owner'),
  family('family'),
  employee('employee');

  const UserRole(this.storedValue);

  /// Value persisted in the drift `role` column.
  final String storedValue;

  static UserRole fromStoredValue(String value) => UserRole.values.firstWhere(
    (role) => role.storedValue == value,
    orElse: () => UserRole.owner,
  );
}
