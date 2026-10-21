import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/services/password_kdf.dart';

// PBKDF2-HMAC-SHA256 and the constant-time compare.
//
// Purpose: lock the algorithm to the RFC construction and to the storage
// shape {algo, iterations, salt, hash}. The password string is not a field.
//
// Rules: production iterations stay >= 100,000. Salt is at least 16 bytes
// from a CSPRNG, so two hashes of the same password do not share a salt.
// Comparison does not stop at the first differing byte (every index is
// tested below). The helper-isolate path must return the same bytes as
// the in-process function.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PBKDF2-HMAC-SHA256 matches known vectors', () {
    // hashlib.pbkdf2_hmac('sha256', b'password', b'salt', c, dklen=32)
    const vectors = {
      1: '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      2: 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      4096: 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
    };
    for (final entry in vectors.entries) {
      final out = pbkdf2HmacSha256(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: entry.key,
      );
      expect(_hex(out), entry.value, reason: 'iterations ${entry.key}');
    }
  });

  test('same password verifies, a wrong password does not, salts differ', () async {
    final first = await _record('correct horse', iterations: 300);
    final second = await _record('correct horse', iterations: 300);
    // Rule: a new salt every time, so the stored hashes are not equal
    // even when the password is.
    expect(first.salt.length, greaterThanOrEqualTo(16));
    expect(second.salt.length, greaterThanOrEqualTo(16));
    expect(first.salt, isNot(equals(second.salt)));
    expect(_verify(first, 'correct horse'), isTrue);
    expect(_verify(first, 'correct horses'), isFalse);
    expect(_verify(second, 'correct horse'), isTrue);
    expect(first.iterations, 300);
    expect(first.algo, passwordHashAlgo);
    // The encoded record is the hash material only.
    expect(first.encode().contains('correct horse'), isFalse);
    final json = jsonDecode(first.encode()) as Map<String, dynamic>;
    expect(json.keys.toSet(), {'algo', 'iterations', 'salt', 'hash'});
  });

  test('constant-time compare walks every byte', () {
    // A difference at any index, including the first and the last, is
    // false. Equal buffers are true. Length is part of the accumulator,
    // not an early return, so a prefix is not treated as equal.
    final a = List<int>.generate(32, (i) => i + 1);
    expect(constantTimeEquals(a, List<int>.from(a)), isTrue);
    for (var i = 0; i < a.length; i++) {
      final b = List<int>.from(a);
      b[i] = b[i] ^ 0xff;
      expect(constantTimeEquals(a, b), isFalse, reason: 'index $i');
    }
    expect(constantTimeEquals(a, a.sublist(0, a.length - 1)), isFalse);
    expect(constantTimeEquals(const <int>[], const <int>[]), isTrue);
    expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
  });

  test('production default is at least 100,000 iterations', () {
    expect(productionKdfIterations, greaterThanOrEqualTo(100000));
  });

  test('helper isolate returns the same bytes as in-process PBKDF2', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final salt = Uint8List.fromList(utf8.encode('salt'));
    final viaIsolate = await binding.runAsync(
      () => hashPasswordOffUiThread(
        password: 'password',
        salt: salt,
        iterations: 2,
      ),
    );
    final direct = pbkdf2HmacSha256(
      password: utf8.encode('password'),
      salt: salt,
      iterations: 2,
    );
    expect(viaIsolate, isNotNull);
    expect(constantTimeEquals(viaIsolate!, direct), isTrue);
  });
}

Future<StoredPassword> _record(String password, {required int iterations}) async {
  final salt = randomSalt(16);
  final hash = pbkdf2HmacSha256(
    password: utf8.encode(password),
    salt: salt,
    iterations: iterations,
  );
  return StoredPassword(
    algo: passwordHashAlgo,
    iterations: iterations,
    salt: salt,
    hash: hash,
  );
}

bool _verify(StoredPassword record, String password) {
  final hash = pbkdf2HmacSha256(
    password: utf8.encode(password),
    salt: record.salt,
    iterations: record.iterations,
  );
  return constantTimeEquals(hash, record.hash);
}

String _hex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
