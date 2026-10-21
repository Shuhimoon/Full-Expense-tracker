import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lock. Launch with the pref on starts locked and prompts immediately;
/// success clears the gate. A failed prompt does not turn the lock on
/// (fail closed). Passcode versus biometrics is `LocalDeviceAuth`
/// (`biometricOnly: false`); this file fakes [DeviceAuth].

class _Gate implements DeviceAuth {
  bool allow = true;
  int calls = 0;

  @override
  Future<bool> authenticate({required String reason}) async {
    calls++;
    return allow;
  }
}

void main() {
  test('lock toggle persists and launch starts locked when enabled', () async {
    SharedPreferences.setMockInitialValues({lockEnabledKey: true});
    final gate = _Gate();
    final lock = LockController(
      auth: gate,
      observeLifecycle: false,
    );
    await lock.bootstrap();
    expect(lock.enabled, isTrue);
    expect(lock.locked, isFalse);
    expect(gate.calls, 1);

    await lock.setEnabled(false);
    expect(lock.enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(lockEnabledKey), isFalse);
  });

  test('failed auth does not enable the lock', () async {
    SharedPreferences.setMockInitialValues({});
    final gate = _Gate()..allow = false;
    final lock = LockController(auth: gate, observeLifecycle: false);
    await lock.bootstrap();
    await lock.setEnabled(true);
    expect(lock.enabled, isFalse);
  });
}
