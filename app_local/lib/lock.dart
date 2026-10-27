import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:full_jizhang/services/password_kdf.dart';
import 'package:full_jizhang/services/secure_store.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App lock. Local only: the ledger has no account password.
//
// Purpose: keep the book covered until the user passes a local check.
// The check is a password the app stores as a salted slow hash. Face ID
// is an optional shortcut on top of that password, not a lock by itself.
//
// Rules enforced by [LockController]:
// - Lock off (no password record, no legacy flag): launch and resume open
//   straight into the ledger. No prompt.
// - Lock on: [locked] starts true, so the first frame is the splash, not
//   帳本. Launch and a return from background set [locked] before any
//   biometric prompt returns. 0s grace: cover on paused/hidden; Face ID
//   then password on resumed. inactive is ignored so the Face ID sheet
//   cannot loop. Biometrics run with biometricOnly: true. Cancel or
//   failure leaves the password field.
// - Enabling the password lock needs a new password and a matching
//   confirmation, each at least [minPasswordLength] characters, not trimmed.
// - Disabling the lock or changing the password needs the current password.
//   A wrong current password counts toward the delay below. Turning the
//   password lock off also turns Face ID off.
// - Face ID can be turned on only while a password record exists. The
//   switch prompts with biometricOnly: true. A failed prompt leaves it off.
// - Five consecutive wrong passwords start a delay of 30s, then 60s, 120s,
//   doubling up to [lockoutCap]. The count and the absolute deadline are
//   in secure storage, so killing the process does not reset them. A
//   correct password or a successful Face ID prompt resets both. Guesses
//   during a delay are refused and do not add another failure.
// - Migration: if SharedPreferences [lockEnabledKey] is true and no
//   password record exists, this is the old Face-ID-only lock. The next
//   launch stays locked and asks for biometrics or the device passcode
//   (biometricOnly: false, because there is no app password yet). After
//   that succeeds, the user must set a password (new model) or decline.
//   Decline clears the legacy flag and Face ID. Decline before that
//   device-auth success does nothing, so a stranger cannot turn the lock
//   off. Once a password is stored, the legacy flag is cleared and the
//   new rules apply. Face ID stays off until the user opts in; the
//   migration prompt only proved device ownership so they could set a
//   password.
//
// Key logic: [ready] starts false and [locked] starts true. [LockGate]
// covers the app until [bootstrap] finishes, then covers it again whenever
// [locked] is true. The KDF runs through [hasher], which by default is
// [hashPasswordOffUiThread].

/// Old Face-ID-only switch. Still read so existing installs migrate.
/// New installs do not use this as the source of truth; the password
/// record in secure storage is.
const lockEnabledKey = 'lock_enabled';

/// Minimum password length. Counted on the raw string, including spaces.
const minPasswordLength = 4;

/// Wrong answers that are free. The attempt at this count starts the delay.
const lockoutStartsAt = 5;

/// First delay, applied on attempt [lockoutStartsAt]. Later attempts double.
const lockoutBase = Duration(seconds: 30);

/// Ceiling for the doubling delay.
const lockoutCap = Duration(hours: 1);

const passwordTooShortMessage = '密碼至少 4 個字';
const passwordMismatchMessage = '兩次輸入的密碼不一致';
const passwordWrongMessage = '密碼不正確';
const biometricNeedsPasswordMessage = '請先開啟密碼鎖。生物辨識不能單獨使用';
const biometricFailedMessage = '無法使用生物辨識';
const lockStorageFailedMessage = '無法讀取鎖定設定';

/// Seconds, rounded up, so a 1 ms remainder still says 1 second.
String lockoutMessage(Duration remaining) {
  final ms = remaining.inMilliseconds;
  final seconds = ms <= 0 ? 1 : (ms + 999) ~/ 1000;
  return '密碼錯誤次數過多，請 $seconds 秒後再試';
}

/// User-facing line for a failed lock operation. Null when [result] is ok.
String? messageForLockResult(
  LockResult result, {
  Duration lockout = Duration.zero,
}) {
  switch (result) {
    case LockResult.ok:
      return null;
    case LockResult.tooShort:
      return passwordTooShortMessage;
    case LockResult.mismatch:
      return passwordMismatchMessage;
    case LockResult.wrong:
      if (lockout > Duration.zero) return lockoutMessage(lockout);
      return passwordWrongMessage;
    case LockResult.lockedOut:
      return lockoutMessage(lockout);
    case LockResult.unavailable:
      return '無法完成這個操作';
    case LockResult.noPassword:
      return '尚未設定密碼';
  }
}

/// Delay for [consecutiveFailures] wrong answers in a row.
///
/// 1–4 → zero. 5 → 30s. 6 → 60s. 7 → 120s. Doubling stops at [lockoutCap].
Duration lockoutDelayForFailures(int consecutiveFailures) {
  if (consecutiveFailures < lockoutStartsAt) return Duration.zero;
  var seconds = lockoutBase.inSeconds;
  final steps = consecutiveFailures - lockoutStartsAt;
  for (var i = 0; i < steps; i++) {
    if (seconds >= lockoutCap.inSeconds) return lockoutCap;
    final doubled = seconds * 2;
    seconds = doubled > lockoutCap.inSeconds ? lockoutCap.inSeconds : doubled;
  }
  return Duration(seconds: seconds);
}

/// Outcome of a password or Face ID change. The UI maps this to text.
enum LockResult {
  ok,
  tooShort,
  mismatch,
  wrong,
  lockedOut,
  unavailable,
  noPassword,
}

/// Keys inside [SecureStore]. Values are the hash record, a decimal
/// counter, an epoch millisecond deadline, and `'1'` for Face ID.
abstract final class LockStorageKeys {
  static const passwordRecord = 'lock.password.v1';
  static const failedAttempts = 'lock.failed_attempts.v1';
  static const lockedUntilMs = 'lock.locked_until_ms.v1';
  static const biometrics = 'lock.biometrics.v1';
}

/// Device authenticator. Tests inject a fake.
///
/// [biometricOnly] is true for the password-lock Face ID path, because
/// the password field is the fallback. Migration passes false so the
/// device passcode still opens the old Face-ID-only gate.
abstract class DeviceAuth {
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  });
}

/// System authenticator. Any plugin error returns false (fail closed).
class LocalDeviceAuth implements DeviceAuth {
  LocalDeviceAuth({LocalAuthentication? plugin})
    : _plugin = plugin ?? LocalAuthentication();

  final LocalAuthentication _plugin;

  @override
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    try {
      return await _plugin.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          // Password lock: Face ID / fingerprint only. The in-app password
          // is the fallback, so the system passcode must not skip it.
          // Migration sets biometricOnly false; there is no app password yet.
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Test double that always unlocks. Production uses [LocalDeviceAuth].
class AlwaysAllowAuth implements DeviceAuth {
  @override
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async => true;
}

/// Whether the app is locked, and the only writes to the lock secrets.
class LockController extends ChangeNotifier with WidgetsBindingObserver {
  LockController({
    required this.auth,
    SecureStore? store,
    SharedPreferences? prefs,
    PasswordHasher? hasher,
    this.kdfIterations = productionKdfIterations,
    DateTime Function()? clock,
    this.observeLifecycle = true,
  }) : store = store ?? const FlutterSecureStore(),
       hasher = hasher ?? hashPasswordOffUiThread,
       _clock = clock ?? DateTime.now {
    // Kept off the initializer list so tests can pass [prefs] by name
    // without exposing the private field as a constructor parameter.
    _prefs = prefs;
    // A zero or negative count would make PBKDF2 throw or become a single
    // HMAC. Refuse that here so a bad injection cannot ship a weak hash.
    if (kdfIterations < 1) {
      throw ArgumentError.value(kdfIterations, 'kdfIterations', 'must be >= 1');
    }
  }

  final DeviceAuth auth;
  final SecureStore store;

  /// Production leaves this null so the KDF runs via [Isolate.run].
  final PasswordHasher hasher;

  /// Written into new records. Verification uses the stored count.
  final int kdfIterations;

  final bool observeLifecycle;
  final DateTime Function() _clock;
  SharedPreferences? _prefs;

  /// True once [bootstrap] has read storage. The gate stays up until then.
  bool ready = false;

  /// Session gate. Starts true so the first frame cannot show the ledger
  /// before we know the lock is off.
  bool locked = true;

  /// Password record is present. This is the 密碼鎖 switch.
  bool passwordEnabled = false;

  /// Face ID shortcut. Ignored unless [passwordEnabled].
  bool biometricsEnabled = false;

  /// Old Face-ID-only install that still needs a password choice.
  bool needsMigration = false;

  /// Device auth for migration succeeded in this session. The set-password
  /// form and the decline action both require this.
  bool migrationReady = false;

  /// Keystore read failed. The gate stays up and offers a retry.
  bool storageFailed = false;

  /// Consecutive wrong passwords. Reset only by a correct password or Face ID.
  int failedAttempts = 0;

  /// Absolute deadline of the current delay. Null when no delay is armed.
  /// A deadline in the past means the wait is over but the counter remains,
  /// so the next wrong answer takes the next step up.
  DateTime? lockedUntil;

  bool _disposed = false;
  bool _prompting = false;
  bool _observing = false;
  /// True after [AppLifecycleState.paused] / [hidden] while the lock is on.
  /// Resume without this flag is the Face ID sheet coming back, not a
  /// real return from background, so we must not re-lock.
  bool _wasBackgrounded = false;
  Future<void>? _bootstrapInFlight;

  /// True when a lock should cover the app (password or legacy migration).
  bool get enabled => passwordEnabled || needsMigration;

  DateTime _now() => _clock();

  /// Time left in the current delay. Zero when the user may try a password.
  Duration get lockoutRemaining {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_now());
    if (left <= Duration.zero) return Duration.zero;
    return left;
  }

  bool get isLockedOut => lockoutRemaining > Duration.zero;

  /// Reads storage and applies the cold-start rule.
  ///
  /// Key logic: [locked] is already true. It is cleared only when there is
  /// no password and no legacy flag. A password record wins over the legacy
  /// flag: the flag is cleared so a later disable cannot resurrect migration.
  /// A legacy flag with no record keeps the gate up and prompts device auth.
  /// Safe to call again after [storageFailed]; a second call re-reads.
  Future<void> bootstrap() {
    final running = _bootstrapInFlight;
    if (running != null) return running;
    final run = _bootstrap();
    _bootstrapInFlight = run;
    return run.whenComplete(() {
      _bootstrapInFlight = null;
    });
  }

  Future<void> _bootstrap() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final record = await _readRecord();
      final legacy = _prefs!.getBool(lockEnabledKey) ?? false;
      await _readThrottle();
      final storedBiometrics = await _readBiometricsFlag();
      storageFailed = false;
      if (record != null) {
        // New model. Drop the legacy flag so it cannot outlive the password.
        passwordEnabled = true;
        needsMigration = false;
        migrationReady = false;
        biometricsEnabled = storedBiometrics;
        if (!storedBiometrics) await _writeBiometricsFlag(false);
        if (legacy) await _prefs!.setBool(lockEnabledKey, false);
        locked = true;
      } else if (legacy) {
        // Migration: keep the old biometric / device-passcode gate, then
        // ask for a password. Face ID as a new-model shortcut stays off
        // until they opt in after a password exists.
        passwordEnabled = false;
        needsMigration = true;
        migrationReady = false;
        biometricsEnabled = false;
        await _writeBiometricsFlag(false);
        locked = true;
      } else {
        passwordEnabled = false;
        needsMigration = false;
        migrationReady = false;
        biometricsEnabled = false;
        if (storedBiometrics) await _writeBiometricsFlag(false);
        locked = false;
      }
    } catch (_) {
      // Fail closed: we could not prove the lock is off.
      storageFailed = true;
      locked = true;
      passwordEnabled = false;
      needsMigration = false;
    }
    ready = true;
    _notify();
    _listenLifecycle();
    if (locked && !storageFailed) {
      await unlock();
    }
  }

  void _listenLifecycle() {
    if (!observeLifecycle || _observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Purpose: cover the ledger the moment the app is no longer visible,
    // then demand Face ID / password when it is visible again.
    //
    // 0s grace: lock on paused/hidden immediately. A short delay would
    // leave a frame of 帳本 in the app switcher; there is no in-app
    // reason to wait.
    //
    // Rule: ignore [AppLifecycleState.inactive]. Face ID and the system
    // passcode sheet put the activity in inactive without a real
    // background. Locking then would call [unlock] again and loop the
    // prompt. [_prompting] also swallows paused/hidden/resumed for the
    // same reason while the sheet is up. Only a paused/hidden that
    // happened while we were not prompting counts as a real background
    // ([_wasBackgrounded]), so the leftover resumed after Face ID is
    // ignored.
    if (_prompting) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _lockForBackground();
      case AppLifecycleState.resumed:
        if (!_wasBackgrounded) return;
        _wasBackgrounded = false;
        unawaited(relockOnResume());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        return;
    }
  }

  /// Covers the book as soon as the process is no longer visible.
  ///
  /// Key logic: [locked] flips true synchronously so the next frame is
  /// the lock UI, not 帳本. Unlock is not attempted here — Face ID
  /// would fail in the background. [relockOnResume] runs the prompt.
  void _lockForBackground() {
    if (!enabled) return;
    _wasBackgrounded = true;
    if (locked) return;
    locked = true;
    migrationReady = false;
    _notify();
  }

  /// Covers the app on resume, then tries Face ID or the migration prompt.
  ///
  /// Rule: a lock that is off does nothing, so backgrounding an unlocked
  /// install does not invent a prompt. Migration must pass device auth
  /// again; [migrationReady] from before the background is dropped.
  Future<void> relockOnResume() async {
    if (!enabled) return;
    locked = true;
    migrationReady = false;
    _notify();
    await unlock();
  }

  /// Turns 密碼鎖 on. Does not replace an existing password; use
  /// [changePassword]. Refuses during migration so device auth is not skipped.
  Future<LockResult> enablePassword(String password, String confirmation) async {
    if (passwordEnabled || needsMigration) return LockResult.unavailable;
    final format = _checkNew(password, confirmation);
    if (format != LockResult.ok) return format;
    final wrote = await _storeNewPassword(password);
    if (!wrote) return LockResult.unavailable;
    passwordEnabled = true;
    needsMigration = false;
    migrationReady = false;
    locked = false;
    await _clearLegacyFlag();
    _notify();
    return LockResult.ok;
  }

  /// Turns 密碼鎖 off. Requires the current password. Also clears Face ID.
  Future<LockResult> disablePassword(String current) async {
    if (!passwordEnabled) return LockResult.unavailable;
    final check = await _checkCurrent(current);
    if (check != LockResult.ok) return check;
    await store.delete(LockStorageKeys.passwordRecord);
    biometricsEnabled = false;
    await _writeBiometricsFlag(false);
    passwordEnabled = false;
    needsMigration = false;
    migrationReady = false;
    locked = false;
    await _clearLegacyFlag();
    await _clearFailures();
    _notify();
    return LockResult.ok;
  }

  /// Replaces the hash. The current password is checked first, so a short
  /// or mismatched new password cannot be used to skip the failure counter.
  Future<LockResult> changePassword({
    required String current,
    required String next,
    required String confirmation,
  }) async {
    if (!passwordEnabled) return LockResult.noPassword;
    final check = await _checkCurrent(current);
    if (check != LockResult.ok) return check;
    final format = _checkNew(next, confirmation);
    if (format != LockResult.ok) return format;
    final wrote = await _storeNewPassword(next);
    if (!wrote) return LockResult.unavailable;
    _notify();
    return LockResult.ok;
  }

  /// Face ID switch.
  ///
  /// Rule: off when there is no password, even if a caller bypasses the
  /// disabled switch in 設定. This is the controller rule, not only UI.
  /// Turning on requires a successful biometricOnly prompt.
  /// Turning off does not require the password; disabling the password lock
  /// is what forces Face ID off.
  Future<LockResult> setBiometrics(bool value) async {
    if (!passwordEnabled) return LockResult.unavailable;
    if (value) {
      final ok = await auth.authenticate(
        reason: '使用 Face ID 解鎖 Full 記帳',
        biometricOnly: true,
      );
      if (!ok) return LockResult.unavailable;
    }
    biometricsEnabled = value;
    await _writeBiometricsFlag(value);
    _notify();
    return LockResult.ok;
  }

  /// Password typed on the lock screen.
  ///
  /// Rule: during a delay the password is not hashed and the counter does
  /// not move, including when the typed password would have been correct.
  /// A wrong password outside a delay increments the counter and, from the
  /// fifth, arms the next delay and covers the app (so 設定 cannot keep
  /// guessing). Success clears the counter and the gate.
  Future<LockResult> submitPassword(String password) async {
    if (!passwordEnabled) return LockResult.noPassword;
    if (isLockedOut) {
      locked = true;
      _notify();
      return LockResult.lockedOut;
    }
    final record = await _readRecord();
    if (record == null) return LockResult.noPassword;
    final ok = await _matches(record, password);
    if (ok == null) return LockResult.unavailable;
    if (!ok) {
      await _noteFailure();
      return LockResult.wrong;
    }
    await _clearFailures();
    locked = false;
    _notify();
    return LockResult.ok;
  }

  /// Saves the migration password after device auth.
  ///
  /// Rule: same length and match checks as [enablePassword]. [migrationReady]
  /// is required. Face ID is left off; the user turns it on in 設定.
  Future<LockResult> completeMigration(
    String password,
    String confirmation,
  ) async {
    if (!needsMigration || !migrationReady) return LockResult.unavailable;
    final format = _checkNew(password, confirmation);
    if (format != LockResult.ok) return format;
    final wrote = await _storeNewPassword(password);
    if (!wrote) return LockResult.unavailable;
    passwordEnabled = true;
    needsMigration = false;
    migrationReady = false;
    biometricsEnabled = false;
    await _writeBiometricsFlag(false);
    locked = false;
    await _clearLegacyFlag();
    _notify();
    return LockResult.ok;
  }

  /// Clears the old Face-ID-only lock.
  ///
  /// Rule: only after [migrationReady]. Before that, this returns
  /// [LockResult.unavailable] and leaves the gate up.
  Future<LockResult> declineMigration() async {
    if (!needsMigration || !migrationReady) return LockResult.unavailable;
    needsMigration = false;
    migrationReady = false;
    passwordEnabled = false;
    biometricsEnabled = false;
    await _writeBiometricsFlag(false);
    locked = false;
    await _clearLegacyFlag();
    _notify();
    return LockResult.ok;
  }

  /// Prompts biometrics, or device auth during migration.
  ///
  /// Key logic: a password-only lock returns without a prompt so the field
  /// is the whole UI. A failed prompt leaves [locked] true. Two overlapping
  /// calls (launch plus a tap) collapse via [_prompting].
  Future<void> unlock() async {
    if (!locked || _prompting || storageFailed) return;
    if (needsMigration && migrationReady) return;
    if (passwordEnabled && !biometricsEnabled) return;
    if (!passwordEnabled && !needsMigration) return;
    _prompting = true;
    try {
      if (needsMigration) {
        final ok = await auth.authenticate(
          reason: '驗證以設定密碼鎖',
          biometricOnly: false,
        );
        if (ok) {
          migrationReady = true;
          // Stay locked until they set a password or decline.
          _notify();
        }
        return;
      }
      if (biometricsEnabled) {
        final ok = await auth.authenticate(
          reason: '解鎖 Full 記帳',
          biometricOnly: true,
        );
        if (ok) {
          await _clearFailures();
          locked = false;
          _notify();
        }
      }
    } finally {
      _prompting = false;
    }
  }

  LockResult _checkNew(String password, String confirmation) {
    // Not trimmed: the lock screen hashes the same bytes the dialog stored.
    if (password.length < minPasswordLength) return LockResult.tooShort;
    if (password != confirmation) return LockResult.mismatch;
    return LockResult.ok;
  }

  /// Checks [password] against the stored record.
  ///
  /// A hasher failure returns null so the counter does not move for an
  /// isolate error. Wrong passwords return false and the caller counts them.
  Future<LockResult> _checkCurrent(String password) async {
    if (isLockedOut) {
      locked = true;
      _notify();
      return LockResult.lockedOut;
    }
    final record = await _readRecord();
    if (record == null) return LockResult.noPassword;
    final ok = await _matches(record, password);
    if (ok == null) return LockResult.unavailable;
    if (!ok) {
      await _noteFailure();
      return LockResult.wrong;
    }
    await _clearFailures();
    return LockResult.ok;
  }

  Future<bool?> _matches(StoredPassword record, String password) async {
    // Unknown algo, short salt, or a huge iteration count: do not run it.
    if (record.algo != passwordHashAlgo) return false;
    if (record.salt.length < passwordSaltLength) return false;
    if (record.iterations < 1 || record.iterations > maxKdfIterations) {
      return false;
    }
    try {
      final hash = await hasher(
        password: password,
        salt: record.salt,
        iterations: record.iterations,
      );
      return constantTimeEquals(hash, record.hash);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _storeNewPassword(String password) async {
    try {
      final salt = randomSalt(passwordSaltLength);
      final hash = await hasher(
        password: password,
        salt: salt,
        iterations: kdfIterations,
      );
      final record = StoredPassword(
        algo: passwordHashAlgo,
        iterations: kdfIterations,
        salt: salt,
        hash: hash,
      );
      // The password string is not part of [record] and is not written.
      await store.write(LockStorageKeys.passwordRecord, record.encode());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _noteFailure() async {
    failedAttempts += 1;
    final delay = lockoutDelayForFailures(failedAttempts);
    if (delay > Duration.zero) {
      lockedUntil = _now().add(delay);
      // Cover 設定 as well as the lock screen, so the dialog cannot be
      // used to keep guessing after the fifth miss.
      locked = true;
    } else {
      lockedUntil = null;
    }
    await _persistThrottle();
    _notify();
  }

  Future<void> _clearFailures() async {
    failedAttempts = 0;
    lockedUntil = null;
    await store.delete(LockStorageKeys.failedAttempts);
    await store.delete(LockStorageKeys.lockedUntilMs);
  }

  Future<void> _persistThrottle() async {
    await store.write(LockStorageKeys.failedAttempts, '$failedAttempts');
    final until = lockedUntil;
    if (until == null) {
      await store.delete(LockStorageKeys.lockedUntilMs);
    } else {
      await store.write(
        LockStorageKeys.lockedUntilMs,
        '${until.millisecondsSinceEpoch}',
      );
    }
  }

  Future<void> _readThrottle() async {
    final attemptsRaw = await store.read(LockStorageKeys.failedAttempts);
    final attempts = int.tryParse(attemptsRaw ?? '') ?? 0;
    failedAttempts = attempts < 0 ? 0 : attempts;
    final untilRaw = await store.read(LockStorageKeys.lockedUntilMs);
    final untilMs = int.tryParse(untilRaw ?? '');
    lockedUntil = untilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(untilMs);
  }

  Future<StoredPassword?> _readRecord() async {
    final raw = await store.read(LockStorageKeys.passwordRecord);
    return StoredPassword.tryDecode(raw);
  }

  Future<bool> _readBiometricsFlag() async {
    return (await store.read(LockStorageKeys.biometrics)) == '1';
  }

  Future<void> _writeBiometricsFlag(bool value) async {
    if (value) {
      await store.write(LockStorageKeys.biometrics, '1');
    } else {
      await store.delete(LockStorageKeys.biometrics);
    }
  }

  Future<void> _clearLegacyFlag() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(lockEnabledKey, false);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.dispose();
  }
}

/// Provides [LockController]. The gate, 設定, and the link host read it.
class LockScope extends InheritedNotifier<LockController> {
  const LockScope({
    super.key,
    required LockController lock,
    required super.child,
  }) : super(notifier: lock);

  static LockController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LockScope>();
    assert(scope != null, 'LockScope is missing above this context');
    return scope!.notifier!;
  }

  /// Read without registering a dependency. For async work outside build,
  /// such as deciding whether a deep link may present a sheet.
  static LockController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<LockScope>();
    assert(element != null, 'LockScope is missing above this context');
    final scope = element!.widget as LockScope;
    return scope.notifier!;
  }
}
