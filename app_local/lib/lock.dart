import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App lock. This is local-only: Go has sessions, not a device lock.
//
// Flow (fail closed):
// - Launch: [LockController.bootstrap] reads [lockEnabledKey]. If the lock is
//   on, [locked] is set true before the prompt, then [unlock] runs. A false
//   or thrown authenticator result leaves the gate up.
// - Resume: [didChangeAppLifecycleState] sets [locked] true as soon as the
//   app returns to the foreground, then prompts again.
// - Enable: [setEnabled] only persists true after a successful prompt. A
//   failure leaves the switch off.
// - Passcode: [LocalDeviceAuth] sets biometricOnly false, so Face ID,
//   fingerprint, and the device passcode are all accepted.

/// SharedPreferences key for whether the lock is turned on.
const lockEnabledKey = 'lock_enabled';

/// Device authenticator. Tests inject a fake so the gate can be forced open
/// or closed without hardware.
abstract class DeviceAuth {
  /// Returns true only when the user passed biometrics or the device passcode.
  Future<bool> authenticate({required String reason});
}

/// System authenticator. Any plugin error returns false (fail closed).
class LocalDeviceAuth implements DeviceAuth {
  LocalDeviceAuth({LocalAuthentication? plugin})
    : _plugin = plugin ?? LocalAuthentication();

  final LocalAuthentication _plugin;

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _plugin.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Passcode is the fallback when biometrics are missing or fail.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      // Plugin missing, cancelled, or locked out: stay locked.
      return false;
    }
  }
}

/// Test double that always unlocks. Production uses [LocalDeviceAuth].
class AlwaysAllowAuth implements DeviceAuth {
  @override
  Future<bool> authenticate({required String reason}) async => true;
}

/// Whether the app is locked, and the prompts that change that.
///
/// [enabled] is the user setting. [locked] is the gate. They differ while
/// the user is inside an unlocked session. See the file comment for launch,
/// resume, passcode fallback, and fail-closed behavior.
class LockController extends ChangeNotifier with WidgetsBindingObserver {
  LockController({
    required this.auth,
    this._prefs,
    this.observeLifecycle = true,
  });

  final DeviceAuth auth;
  SharedPreferences? _prefs;
  final bool observeLifecycle;

  bool enabled = false;
  bool locked = false;
  bool ready = false;
  bool _disposed = false;
  bool _prompting = false;

  /// Reads the saved flag and, when the lock is on, starts locked.
  ///
  /// [locked] is set before [unlock], so a failed prompt never flashes the
  /// ledger. [observeLifecycle] is false in tests that do not have a binding.
  Future<void> bootstrap() async {
    _prefs ??= await SharedPreferences.getInstance();
    enabled = _prefs!.getBool(lockEnabledKey) ?? false;
    // Fail closed: assume locked until authenticate returns true.
    locked = enabled;
    ready = true;
    _notify();
    if (observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    if (locked) {
      await unlock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from background re-locks before the prompt, same as launch.
    if (state == AppLifecycleState.resumed && enabled) {
      locked = true;
      _notify();
      unlock();
    }
  }

  /// Turns the lock on only after a successful prompt.
  ///
  /// A cancelled or failed prompt returns without writing prefs, so the
  /// settings switch stays off.
  Future<void> setEnabled(bool value) async {
    if (value) {
      final ok = await authenticate();
      if (!ok) return;
    }
    enabled = value;
    locked = false;
    await (_prefs ??= await SharedPreferences.getInstance()).setBool(
      lockEnabledKey,
      value,
    );
    _notify();
  }

  Future<bool> authenticate() {
    return auth.authenticate(reason: '解鎖 Full 記帳');
  }

  /// Prompts once. Clears [locked] only when authenticate returns true.
  Future<void> unlock() async {
    // _prompting drops a second prompt from a double tap or a resume that
    // overlaps the launch prompt.
    if (!locked || _prompting) return;
    _prompting = true;
    try {
      final ok = await authenticate();
      if (ok) {
        locked = false;
        _notify();
      }
    } finally {
      _prompting = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (observeLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}

/// Provides [LockController]. [LockGate] and settings read it with [of].
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
}
