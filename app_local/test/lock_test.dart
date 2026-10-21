import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/pages/settings/settings_page.dart';
import 'package:full_jizhang/services/incoming_links.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/services/password_kdf.dart';
import 'package:full_jizhang/services/secure_store.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rules/harness.dart';

// Password lock, Face ID rules, lockout, migration, and the deep-link gate.
//
// The secure store is [MemorySecureStore]. Most cases hash with a few
// hundred PBKDF2 rounds injected into [LockController]. One case uses the
// production iteration count and asserts the stored record is >= 100,000.
// The clock is injected so the delay can be stepped without sleeping.

class _Gate implements DeviceAuth {
  bool allow = true;
  int calls = 0;
  bool? lastBiometricOnly;

  @override
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    calls++;
    lastBiometricOnly = biometricOnly;
    return allow;
  }
}

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

/// Same bytes as production, but on this isolate so widget tests do not
/// have to wait for a helper isolate. Iteration count is still injected.
Future<Uint8List> _inlineHash({
  required String password,
  required Uint8List salt,
  required int iterations,
}) async {
  return pbkdf2HmacSha256(
    password: utf8.encode(password),
    salt: salt,
    iterations: iterations,
    keyLength: passwordHashLength,
  );
}

class _ScriptedLinks implements LinkSource {
  _ScriptedLinks({this.initial});

  Uri? initial;
  final StreamController<Uri> live = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initial;

  @override
  Stream<Uri> get uriLinkStream => live.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    openTestSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('delay doubles from 30s and is capped', () {
    expect(lockoutDelayForFailures(4), Duration.zero);
    expect(lockoutDelayForFailures(5), const Duration(seconds: 30));
    expect(lockoutDelayForFailures(6), const Duration(seconds: 60));
    expect(lockoutDelayForFailures(7), const Duration(seconds: 120));
    expect(lockoutCap, const Duration(hours: 1));
    expect(lockoutDelayForFailures(30), lockoutCap);
    expect(lockoutDelayForFailures(12).inSeconds, lessThanOrEqualTo(3600));
  });

  test('enable needs a match and 4 characters; plaintext is not stored', () async {
    final store = MemorySecureStore();
    final lock = _controller(store: store);
    await lock.bootstrap();
    expect(lock.locked, isFalse);

    expect(await lock.enablePassword('abc', 'abc'), LockResult.tooShort);
    expect(lock.passwordEnabled, isFalse);
    expect(store.data.containsKey(LockStorageKeys.passwordRecord), isFalse);

    expect(await lock.enablePassword('abcd', 'abce'), LockResult.mismatch);
    expect(lock.passwordEnabled, isFalse);

    expect(await lock.enablePassword('abcd', 'abcd'), LockResult.ok);
    expect(lock.passwordEnabled, isTrue);
    expect(lock.locked, isFalse);
    final raw = store.data[LockStorageKeys.passwordRecord]!;
    expect(raw.contains('abcd'), isFalse);
    final record = StoredPassword.tryDecode(raw)!;
    expect(record.algo, passwordHashAlgo);
    expect(record.iterations, 200);
    expect(record.salt.length, greaterThanOrEqualTo(16));
    // A second enable must not overwrite the hash without the current password.
    expect(await lock.enablePassword('zzzz', 'zzzz'), LockResult.unavailable);
    expect(store.data[LockStorageKeys.passwordRecord], raw);
  });

  test('production default iterations are what gets stored', () async {
    expect(productionKdfIterations, greaterThanOrEqualTo(100000));
    final shipped = LockController(
      auth: _Gate(),
      store: MemorySecureStore(),
      observeLifecycle: false,
    );
    expect(shipped.kdfIterations, greaterThanOrEqualTo(100000));
    expect(shipped.hasher, hashPasswordOffUiThread);
    shipped.dispose();

    final store = MemorySecureStore();
    final lock = LockController(
      auth: _Gate(),
      store: store,
      // Inline so the assertion does not depend on isolate scheduling.
      // The iteration count is still the production default.
      hasher: _inlineHash,
      observeLifecycle: false,
    );
    await lock.bootstrap();
    expect(await lock.enablePassword('abcd', 'abcd'), LockResult.ok);
    final record = StoredPassword.tryDecode(
      store.data[LockStorageKeys.passwordRecord],
    )!;
    expect(record.iterations, greaterThanOrEqualTo(100000));
    expect(record.algo, passwordHashAlgo);
    expect(record.salt.length, greaterThanOrEqualTo(16));
    expect(store.data[LockStorageKeys.passwordRecord]!.contains('abcd'), isFalse);
    // One verify at the production count, so the stored hash is a real
    // PBKDF2 output and not only a number written into JSON.
    expect(await lock.submitPassword('abcd'), LockResult.ok);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('disable and change need the current password', () async {
    final store = MemorySecureStore();
    final lock = _controller(store: store);
    await lock.bootstrap();
    await lock.enablePassword('abcd', 'abcd');
    await lock.setBiometrics(true);

    expect(
      await lock.changePassword(current: 'nope', next: 'wxyz', confirmation: 'wxyz'),
      LockResult.wrong,
    );
    expect(await lock.submitPassword('abcd'), LockResult.ok);

    expect(
      await lock.changePassword(current: 'abcd', next: 'xy', confirmation: 'xy'),
      LockResult.tooShort,
    );
    expect(
      await lock.changePassword(current: 'abcd', next: 'wxyz', confirmation: 'wxyy'),
      LockResult.mismatch,
    );
    expect(await lock.submitPassword('abcd'), LockResult.ok);

    expect(
      await lock.changePassword(current: 'abcd', next: 'wxyz', confirmation: 'wxyz'),
      LockResult.ok,
    );
    expect(await lock.submitPassword('abcd'), LockResult.wrong);
    expect(await lock.submitPassword('wxyz'), LockResult.ok);

    expect(await lock.disablePassword('wxyy'), LockResult.wrong);
    expect(lock.passwordEnabled, isTrue);
    expect(lock.biometricsEnabled, isTrue);

    expect(await lock.disablePassword('wxyz'), LockResult.ok);
    expect(lock.passwordEnabled, isFalse);
    expect(lock.biometricsEnabled, isFalse);
    expect(store.data.containsKey(LockStorageKeys.passwordRecord), isFalse);
    expect(store.data.containsKey(LockStorageKeys.biometrics), isFalse);
    expect(await lock.submitPassword('wxyz'), LockResult.noPassword);
  });

  test('biometrics require the password lock', () async {
    final auth = _Gate();
    final lock = _controller(auth: auth);
    await lock.bootstrap();

    expect(await lock.setBiometrics(true), LockResult.unavailable);
    expect(lock.biometricsEnabled, isFalse);
    expect(auth.calls, 0);

    await lock.enablePassword('abcd', 'abcd');
    auth.allow = false;
    expect(await lock.setBiometrics(true), LockResult.unavailable);
    expect(lock.biometricsEnabled, isFalse);
    expect(auth.lastBiometricOnly, isTrue);

    auth.allow = true;
    expect(await lock.setBiometrics(true), LockResult.ok);
    expect(lock.biometricsEnabled, isTrue);
    expect(auth.lastBiometricOnly, isTrue);

    await lock.disablePassword('abcd');
    expect(lock.biometricsEnabled, isFalse);
    expect(await lock.setBiometrics(true), LockResult.unavailable);
  });

  test('five wrong passwords start a delay that survives a new controller', () async {
    final clock = _Clock(DateTime.utc(2026, 1, 1));
    final store = MemorySecureStore();
    final lock = _controller(store: store, clock: clock.call);
    await lock.bootstrap();
    await lock.enablePassword('abcd', 'abcd');

    for (var i = 1; i <= 4; i++) {
      expect(await lock.submitPassword('nope'), LockResult.wrong);
      expect(lock.failedAttempts, i);
      expect(lock.lockoutRemaining, Duration.zero);
      expect(lock.locked, isFalse);
    }
    expect(await lock.submitPassword('nope'), LockResult.wrong);
    expect(lock.failedAttempts, 5);
    expect(lock.lockoutRemaining, const Duration(seconds: 30));
    expect(lock.locked, isTrue);
    // The right password is refused too, and the counter does not move.
    expect(await lock.submitPassword('abcd'), LockResult.lockedOut);
    expect(lock.failedAttempts, 5);

    final restarted = _controller(store: store, clock: clock.call);
    await restarted.bootstrap();
    expect(restarted.failedAttempts, 5);
    expect(restarted.passwordEnabled, isTrue);
    expect(restarted.locked, isTrue);
    expect(restarted.lockoutRemaining, const Duration(seconds: 30));
    expect(await restarted.submitPassword('abcd'), LockResult.lockedOut);

    clock.now = clock.now.add(const Duration(seconds: 30));
    expect(restarted.lockoutRemaining, Duration.zero);
    expect(await restarted.submitPassword('nope'), LockResult.wrong);
    expect(restarted.failedAttempts, 6);
    expect(restarted.lockoutRemaining, const Duration(seconds: 60));

    clock.now = clock.now.add(const Duration(seconds: 60));
    expect(await restarted.submitPassword('abcd'), LockResult.ok);
    expect(restarted.failedAttempts, 0);
    expect(restarted.locked, isFalse);
    expect(store.data.containsKey(LockStorageKeys.failedAttempts), isFalse);

    final cleared = _controller(store: store, clock: clock.call);
    await cleared.bootstrap();
    expect(cleared.failedAttempts, 0);
    expect(cleared.lockoutRemaining, Duration.zero);
    expect(cleared.locked, isTrue);
  });

  test('a delay that already expired keeps the counter for the next step', () async {
    final clock = _Clock(DateTime.utc(2026, 6, 1));
    final store = MemorySecureStore();
    final lock = _controller(store: store, clock: clock.call);
    await lock.bootstrap();
    await lock.enablePassword('abcd', 'abcd');
    for (var i = 0; i < 5; i++) {
      await lock.submitPassword('nope');
    }
    expect(lock.failedAttempts, 5);
    clock.now = clock.now.add(const Duration(seconds: 31));
    final later = _controller(store: store, clock: clock.call);
    await later.bootstrap();
    expect(later.failedAttempts, 5);
    expect(later.lockoutRemaining, Duration.zero);
    expect(await later.submitPassword('nope'), LockResult.wrong);
    expect(later.failedAttempts, 6);
    expect(later.lockoutRemaining, const Duration(seconds: 60));
  });

  test('Face ID success clears the failure counter', () async {
    final auth = _Gate();
    final lock = _controller(auth: auth);
    await lock.bootstrap();
    await lock.enablePassword('abcd', 'abcd');
    await lock.setBiometrics(true);
    for (var i = 0; i < 3; i++) {
      expect(await lock.submitPassword('nope'), LockResult.wrong);
    }
    expect(lock.failedAttempts, 3);
    auth.calls = 0;
    await lock.relockOnResume();
    expect(lock.locked, isFalse);
    expect(auth.lastBiometricOnly, isTrue);
    expect(lock.failedAttempts, 0);
  });

  test('resume does nothing when the lock is off', () async {
    final lock = _controller();
    await lock.bootstrap();
    expect(lock.locked, isFalse);
    await lock.relockOnResume();
    expect(lock.locked, isFalse);
  });

  test('legacy Face ID lock migrates or clears', () async {
    SharedPreferences.setMockInitialValues({lockEnabledKey: true});
    final auth = _Gate()..allow = false;
    final store = MemorySecureStore();
    final lock = _controller(store: store, auth: auth);
    await lock.bootstrap();
    expect(lock.needsMigration, isTrue);
    expect(lock.passwordEnabled, isFalse);
    expect(lock.locked, isTrue);
    expect(lock.migrationReady, isFalse);
    // Cancelled device auth leaves the old lock in place.
    expect(auth.lastBiometricOnly, isFalse);
    expect(await lock.declineMigration(), LockResult.unavailable);
    expect(await lock.completeMigration('abcd', 'abcd'), LockResult.unavailable);
    expect(lock.locked, isTrue);
    expect((await SharedPreferences.getInstance()).getBool(lockEnabledKey), isTrue);

    auth.allow = true;
    await lock.unlock();
    expect(lock.migrationReady, isTrue);
    expect(lock.locked, isTrue);
    expect(await lock.completeMigration('abc', 'abc'), LockResult.tooShort);
    expect(await lock.completeMigration('abcd', 'abce'), LockResult.mismatch);
    expect(lock.needsMigration, isTrue);

    expect(await lock.declineMigration(), LockResult.ok);
    expect(lock.needsMigration, isFalse);
    expect(lock.locked, isFalse);
    expect(lock.passwordEnabled, isFalse);
    expect(lock.biometricsEnabled, isFalse);
    expect(store.data.containsKey(LockStorageKeys.passwordRecord), isFalse);
    expect((await SharedPreferences.getInstance()).getBool(lockEnabledKey), isFalse);

    final again = _controller(store: store, auth: _Gate());
    await again.bootstrap();
    expect(again.needsMigration, isFalse);
    expect(again.locked, isFalse);
  });

  test('setting a password during migration switches to the new model', () async {
    SharedPreferences.setMockInitialValues({lockEnabledKey: true});
    final auth = _Gate();
    final store = MemorySecureStore();
    final lock = _controller(store: store, auth: auth);
    await lock.bootstrap();
    expect(auth.lastBiometricOnly, isFalse);
    expect(lock.migrationReady, isTrue);
    expect(await lock.completeMigration('abcd', 'abcd'), LockResult.ok);
    expect(lock.passwordEnabled, isTrue);
    expect(lock.needsMigration, isFalse);
    expect(lock.locked, isFalse);
    // Face ID is opt-in after migration. The device prompt only authorized
    // setting the password; it does not turn the new shortcut on.
    expect(lock.biometricsEnabled, isFalse);
    expect(store.data[LockStorageKeys.passwordRecord]!.contains('abcd'), isFalse);
    expect((await SharedPreferences.getInstance()).getBool(lockEnabledKey), isFalse);

    final next = _controller(store: store, auth: _Gate()..allow = false);
    await next.bootstrap();
    expect(next.needsMigration, isFalse);
    expect(next.passwordEnabled, isTrue);
    expect(next.locked, isTrue);
    expect(await next.submitPassword('abcd'), LockResult.ok);
    expect(next.locked, isFalse);
  });

  test('a password record wins over the legacy flag', () async {
    final store = MemorySecureStore();
    final first = _controller(store: store);
    await first.bootstrap();
    await first.enablePassword('abcd', 'abcd');
    // Same prefs object bootstrap already opened. Putting the legacy flag
    // back on must not override the password record.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(lockEnabledKey, true);
    final lock = _controller(store: store);
    await lock.bootstrap();
    expect(lock.needsMigration, isFalse);
    expect(lock.passwordEnabled, isTrue);
    expect(lock.locked, isTrue);
    expect((await SharedPreferences.getInstance()).getBool(lockEnabledKey), isFalse);
  });

  testWidgets('settings toggles follow the password rules', (tester) async {
    final auth = _Gate();
    final lock = _controller(auth: auth);
    await lock.bootstrap();
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final books = BookController(api: LocalApi(db));
    await books.reload();
    addTearDown(books.dispose);
    addTearDown(lock.dispose);

    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LockScope(
        lock: lock,
        child: BookScope(
          books: books,
          // Scaffold supplies the Material ancestor InkWell needs.
          // The real app gets that from the shell.
          child: const MaterialApp(home: Scaffold(body: SettingsPage())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('密碼鎖'), findsOneWidget);
    expect(_switch(tester, 'settings-biometric').onChanged, isNull);
    expect(find.text(biometricNeedsPasswordMessage), findsOneWidget);
    expect(find.byKey(const Key('settings-change-password')), findsNothing);

    await _fillNew(tester, 'ab', 'ab');
    expect(find.text(passwordTooShortMessage), findsOneWidget);
    expect(_switch(tester, 'settings-lock').value, isFalse);

    await _fillNew(tester, 'abcd', 'abce');
    expect(find.text(passwordMismatchMessage), findsOneWidget);
    expect(_switch(tester, 'settings-lock').value, isFalse);

    await _fillNew(tester, 'abcd', 'abcd');
    expect(_switch(tester, 'settings-lock').value, isTrue);
    expect(_switch(tester, 'settings-biometric').onChanged, isNotNull);
    expect(find.byKey(const Key('settings-change-password')), findsOneWidget);
    expect(find.text(biometricNeedsPasswordMessage), findsNothing);

    final bio = find.byKey(const Key('settings-biometric'));
    await tester.ensureVisible(bio);
    await tester.tap(bio);
    await tester.pumpAndSettle();
    expect(_switch(tester, 'settings-biometric').value, isTrue);
    expect(auth.lastBiometricOnly, isTrue);

    final lockSwitch = find.byKey(const Key('settings-lock'));
    await tester.ensureVisible(lockSwitch);
    await tester.tap(lockSwitch);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-password-current')), 'nope');
    await tester.tap(find.byKey(const Key('settings-password-ok')));
    await tester.pumpAndSettle();
    expect(find.text(passwordWrongMessage), findsOneWidget);
    expect(_switch(tester, 'settings-lock').value, isTrue);
    expect(_switch(tester, 'settings-biometric').value, isTrue);

    await tester.ensureVisible(lockSwitch);
    await tester.tap(lockSwitch);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-password-current')), 'abcd');
    await tester.tap(find.byKey(const Key('settings-password-ok')));
    await tester.pumpAndSettle();
    expect(_switch(tester, 'settings-lock').value, isFalse);
    expect(_switch(tester, 'settings-biometric').value, isFalse);
    expect(_switch(tester, 'settings-biometric').onChanged, isNull);
    expect(find.text(biometricNeedsPasswordMessage), findsOneWidget);
  });

  testWidgets('a queued deep link is shown only after unlock', (tester) async {
    final store = MemorySecureStore();
    await _seed(store, 'abcd');
    final lock = _controller(store: store, auth: _Gate()..allow = false);
    final initial = _payLink('launch-1');
    final source = _ScriptedLinks(initial: initial);
    final links = IncomingLinks(source: source);
    addTearDown(source.live.close);
    addTearDown(lock.dispose);

    final db = AppDatabase.memory();
    addTearDown(db.close);
    final api = LocalApi(db);
    await api.createBook(name: '生活');

    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FullJizhangApp(api: api, lock: lock, links: links));
    await tester.pumpAndSettle();

    // Launch link is queued behind the password. The preview is not built.
    expect(find.byKey(const Key('lock-password')), findsOneWidget);
    expect(find.text('匯入預覽'), findsNothing);
    expect(find.text('星巴克'), findsNothing);

    await tester.enterText(find.byKey(const Key('lock-password')), 'abcd');
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();

    expect(find.text('匯入預覽'), findsOneWidget);
    expect(find.text('星巴克'), findsWidgets);
    expect(lock.locked, isFalse);

    await tester.tap(find.byKey(const Key('import-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('匯入預覽'), findsNothing);

    // Resume covers the app again. A link that arrives now stays queued.
    await lock.relockOnResume();
    await tester.pump();
    expect(find.byKey(const Key('lock-password')), findsOneWidget);
    source.live.add(_payLink('resume-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('匯入預覽'), findsNothing);

    await tester.enterText(find.byKey(const Key('lock-password')), 'abcd');
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();
    expect(find.text('匯入預覽'), findsOneWidget);
    expect(lock.locked, isFalse);
  });

  testWidgets('lock off opens straight in and shows the link', (tester) async {
    final lock = _controller();
    final source = _ScriptedLinks(initial: _payLink('open-1'));
    final links = IncomingLinks(source: source);
    addTearDown(source.live.close);
    addTearDown(lock.dispose);

    final db = AppDatabase.memory();
    addTearDown(db.close);
    final api = LocalApi(db);
    await api.createBook(name: '生活');

    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FullJizhangApp(api: api, lock: lock, links: links));
    await tester.pumpAndSettle();

    expect(lock.locked, isFalse);
    expect(find.byKey(const Key('lock-password')), findsNothing);
    expect(find.text('匯入預覽'), findsOneWidget);
  });
}

LockController _controller({
  MemorySecureStore? store,
  _Gate? auth,
  DateTime Function()? clock,
  int iterations = 200,
}) {
  return LockController(
    auth: auth ?? _Gate(),
    store: store ?? MemorySecureStore(),
    hasher: _inlineHash,
    kdfIterations: iterations,
    clock: clock,
    observeLifecycle: false,
  );
}

Future<void> _seed(MemorySecureStore store, String password) async {
  final salt = randomSalt(16);
  final hash = pbkdf2HmacSha256(
    password: utf8.encode(password),
    salt: salt,
    iterations: 200,
  );
  final record = StoredPassword(
    algo: passwordHashAlgo,
    iterations: 200,
    salt: salt,
    hash: hash,
  );
  await store.write(LockStorageKeys.passwordRecord, record.encode());
}

Uri _payLink(String id) {
  return Uri.parse(
    'fulljizhang://add?amount=185&merchant=${Uri.encodeQueryComponent('星巴克')}'
    '&time=2099-01-01T08:00:00%2B08:00&id=$id',
  );
}

Switch _switch(WidgetTester tester, String key) {
  return tester.widget<Switch>(find.byKey(Key(key)));
}

Future<void> _fillNew(WidgetTester tester, String next, String confirm) async {
  final sw = find.byKey(const Key('settings-lock'));
  await tester.ensureVisible(sw);
  await tester.tap(sw);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('settings-password-next')), next);
  await tester.enterText(
    find.byKey(const Key('settings-password-confirm')),
    confirm,
  );
  await tester.tap(find.byKey(const Key('settings-password-ok')));
  await tester.pumpAndSettle();
}
