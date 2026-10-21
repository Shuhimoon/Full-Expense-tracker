import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Key/value store for lock secrets.
//
// Purpose: the password record, the consecutive-failure counter, the
// lockout deadline, and the Face ID flag must survive process death and
// must not sit in SharedPreferences (that file is plaintext on many devices).
//
// Rules:
// - Callers store the salted hash record, never the password.
// - Android does not set enforceBiometrics. If the keystore itself demanded
//   Face ID, the password field could not read the hash when biometrics
//   fail, and the password would not be a fallback.
// - resetOnError is false. The plugin's default wipes the entry on some
//   keystore errors, which would delete the hash and open the app.

/// Persistence for the lock. Tests use [MemorySecureStore].
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production store. Backed by the platform keystore / keychain.
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              // Purpose: keep a keystore error from erasing the hash.
              // Rule: biometric unlock is our own flag plus local_auth,
              // not a second gate inside the keystore.
              aOptions: AndroidOptions(resetOnError: false),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory fake. Production code never constructs this.
///
/// [data] is public so tests can assert the password string was not written.
class MemorySecureStore implements SecureStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}
