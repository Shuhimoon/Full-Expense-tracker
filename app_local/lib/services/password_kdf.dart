import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// On-device password hashing for 密碼鎖.
//
// Purpose: turn a password into a verifier the lock can store. The password
// itself never goes into secure storage, SharedPreferences, or logs.
//
// Rules enforced here:
// - Algorithm is PBKDF2-HMAC-SHA256 (RFC 8018) with a random salt of at
//   least 16 bytes from [Random.secure].
// - Production uses [productionKdfIterations] (100,000 or more). Tests may
//   pass a smaller count into [LockController]; verification always uses
//   the count stored next to the hash, not whatever the process default is.
// - Comparison of the derived key is constant-time. A mismatch on the
//   first byte does not return early.
// - The slow loop runs in a helper isolate ([hashPasswordOffUiThread]) so
//   the UI thread does not hitch while the user waits.

/// Stored `algo` value. Anything else fails verification (fail closed).
const passwordHashAlgo = 'pbkdf2-hmac-sha256';

/// Shipping iteration count. Tests assert this stays at or above 100,000.
const productionKdfIterations = 100000;

/// Reject a stored count above this so a corrupt record cannot pin a core.
const maxKdfIterations = 2000000;

/// Derived-key length in bytes. SHA-256 output, one block.
const passwordHashLength = 32;

/// Minimum salt length. [randomSalt] refuses anything shorter.
const passwordSaltLength = 16;

/// HMAC-SHA256 PBKDF2. [password] and [salt] are raw bytes (password is UTF-8).
///
/// Key logic: `T_i = U_1 xor U_2 xor ... xor U_c` with
/// `U_1 = HMAC(password, salt || INT32BE(i))` and `U_n = HMAC(password, U_{n-1})`.
/// The inner loop reuses two 32-byte buffers so 100,000 rounds do not
/// allocate a fresh list per round.
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  int keyLength = passwordHashLength,
}) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'must be >= 1');
  }
  if (keyLength < 1) {
    throw ArgumentError.value(keyLength, 'keyLength', 'must be >= 1');
  }
  final hmac = Hmac(sha256, password);
  final out = Uint8List(keyLength);
  final u = Uint8List(32);
  final t = Uint8List(32);
  final blocks = (keyLength + 31) ~/ 32;
  var offset = 0;
  for (var block = 1; block <= blocks; block++) {
    final seed = Uint8List(salt.length + 4);
    seed.setRange(0, salt.length, salt);
    // INT(i) is a 32-bit big-endian block index, starting at 1.
    seed[salt.length] = (block >> 24) & 0xff;
    seed[salt.length + 1] = (block >> 16) & 0xff;
    seed[salt.length + 2] = (block >> 8) & 0xff;
    seed[salt.length + 3] = block & 0xff;
    _xorInto(hmac.convert(seed).bytes, u, t, first: true);
    for (var round = 1; round < iterations; round++) {
      _xorInto(hmac.convert(u).bytes, u, t, first: false);
    }
    final take = keyLength - offset < 32 ? keyLength - offset : 32;
    out.setRange(offset, offset + take, t);
    offset += take;
  }
  return out;
}

/// Copies [bytes] into [u] and folds them into [t].
///
/// [first] writes [t]; later rounds XOR. One return, no early exit, so a
/// caller that reuses this for PBKDF2 always pays for all 32 bytes.
void _xorInto(List<int> bytes, Uint8List u, Uint8List t, {required bool first}) {
  for (var i = 0; i < 32; i++) {
    final b = bytes[i];
    u[i] = b;
    if (first) {
      t[i] = b;
    } else {
      t[i] ^= b;
    }
  }
}

/// Constant-time equality for secret bytes (the derived key).
///
/// Rules: the loop always walks the overlapping prefix. Length is mixed
/// into the accumulator with XOR, not with an early `return false`, so
/// the timing does not reveal the first differing index.
bool constantTimeEquals(List<int> a, List<int> b) {
  var diff = a.length ^ b.length;
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// CSPRNG salt. Refuses fewer than [passwordSaltLength] bytes.
///
/// Key logic: [Random.secure] only. There is no fallback to [Random],
/// which would make salts guessable.
Uint8List randomSalt([int length = passwordSaltLength]) {
  if (length < passwordSaltLength) {
    throw ArgumentError.value(
      length,
      'length',
      'salt must be at least $passwordSaltLength bytes',
    );
  }
  final rng = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return bytes;
}

/// What secure storage holds. No field for the password.
class StoredPassword {
  const StoredPassword({
    required this.algo,
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  final String algo;
  final int iterations;
  final Uint8List salt;
  final Uint8List hash;

  /// JSON object `{algo, iterations, salt, hash}`. Salt and hash are base64.
  String encode() {
    return jsonEncode({
      'algo': algo,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
    });
  }

  /// Fail closed: null when the payload is not our object. Callers treat
  /// null as "no password" only after they decide that is safe; a present
  /// but unknown [algo] is still returned so verification can reject it.
  static StoredPassword? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final algo = decoded['algo'];
    final iterations = decoded['iterations'];
    final saltText = decoded['salt'];
    final hashText = decoded['hash'];
    if (algo is! String || algo.isEmpty) return null;
    if (iterations is! int || iterations < 1) return null;
    if (saltText is! String || hashText is! String) return null;
    Uint8List salt;
    Uint8List hash;
    try {
      salt = Uint8List.fromList(base64Decode(saltText));
      hash = Uint8List.fromList(base64Decode(hashText));
    } catch (_) {
      return null;
    }
    if (salt.isEmpty || hash.isEmpty) return null;
    return StoredPassword(
      algo: algo,
      iterations: iterations,
      salt: salt,
      hash: hash,
    );
  }
}

/// Runs [pbkdf2HmacSha256] off the UI isolate.
///
/// Purpose: 100,000 HMAC rounds must not freeze input. The closure captures
/// only a [String], a [Uint8List], and two ints, which [Isolate.run] can send.
/// The password bytes exist in the helper isolate for the duration of the
/// call and are not written anywhere by this function.
Future<Uint8List> hashPasswordOffUiThread({
  required String password,
  required Uint8List salt,
  required int iterations,
}) {
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  final saltBytes = Uint8List.fromList(salt);
  final rounds = iterations;
  final length = passwordHashLength;
  return Isolate.run(
    () => pbkdf2HmacSha256(
      password: passwordBytes,
      salt: saltBytes,
      iterations: rounds,
      keyLength: length,
    ),
  );
}

/// Signature [LockController] calls. Production passes [hashPasswordOffUiThread].
/// Tests inject a same-isolate function with a low iteration count.
typedef PasswordHasher = Future<Uint8List> Function({
  required String password,
  required Uint8List salt,
  required int iterations,
});
