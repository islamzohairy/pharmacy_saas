import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value abstraction over platform secure storage.
///
/// The only concrete implementation is [FlutterSecureStore]; tests inject
/// an in-memory fake instead of fighting the platform channel.
abstract interface class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Real implementation backed by `flutter_secure_storage`.
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
