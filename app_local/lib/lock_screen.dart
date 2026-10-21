import 'dart:async';

import 'package:flutter/material.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/brand_mark.dart';

// Lock UI drawn over the router.
//
// Purpose: collect the local password, offer Face ID when it is on, and
// finish the Face-ID-only migration. Nothing here writes the password to
// disk. [LockController] hashes it and stores the record.
//
// Rules:
// - Before [LockController.ready] the cover is a splash, not a password
//   form, so a lock-off launch does not ask for a password.
// - Password lock tries Face ID from [LockController.unlock] (already
//   called by bootstrap / resume). This screen is the fallback field.
//   The Face ID button retries with biometricOnly: true.
// - While a delay is active the field and the unlock button are disabled.
//   The seconds come from the controller's clock, not from a guess.
// - Migration shows the password form only after device auth. Decline
//   (「不使用密碼鎖」) is the same gate: hidden until that auth succeeds.
// - The cover is a sibling of the Router, so it cannot install a
//   BackButtonListener. It still eats taps. A system back may pop a route
//   underneath; the cover stays up until unlock, so that route is not usable.
// - The password field needs an Overlay for the caret. The navigator's
//   overlay is not an ancestor here, so [LockScreen] supplies a local one.
//   That overlay is not a route and cannot be popped.

/// Non-interactive cover used until [LockController.bootstrap] finishes.
class LockCover extends StatelessWidget {
  const LockCover({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      key: Key('lock-cover'),
      color: AppColors.background,
      child: Center(
        child: Text(
          '載入中…',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ),
    );
  }
}

/// Password, Face ID retry, or migration choice.
///
/// Purpose: host the lock form and give it an [Overlay].
///
/// Rule: the cover sits beside the app Router, so [TextField] cannot see
/// the navigator overlay. A local overlay is created once and is not a
/// route stack. Rebuilding the gate must not insert a second entry.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  // Created once. [Overlay.initialEntries] is read only in initState, so a
  // later rebuild of this state must hand the same entry back.
  late final OverlayEntry _entry = OverlayEntry(
    opaque: true,
    builder: (context) => const _LockForm(),
  );

  @override
  void dispose() {
    // Children unmount first, so the Overlay is already gone and the
    // entry's widget is not mounted. remove() clears the leftover
    // pointer (it does not rebuild a dead overlay); dispose() then
    // releases the entry. Both are required, and only once.
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}

/// The form itself. Kept under the overlay entry so its state (the typed
/// password, the delay timer) survives a gate rebuild.
class _LockForm extends StatefulWidget {
  const _LockForm();

  @override
  State<_LockForm> createState() => _LockFormState();
}

class _LockFormState extends State<_LockForm> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  Timer? _tick;
  String? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Purpose: the delay label must move without a new failed guess.
    // Rule: the timer exists only while a delay is active, and it is
    // cancelled as soon as the deadline passes, so tests that are not
    // locked out do not leak a pending timer.
    final waiting = LockScope.of(context).lockoutRemaining > Duration.zero;
    if (waiting && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        // read, not of: a timer is not a build, so it must not register
        // a new inherited dependency. The label still rebuilds via setState.
        if (!context.mounted) return;
        if (LockScope.read(context).lockoutRemaining <= Duration.zero) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else if (!waiting) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final lock = LockScope.of(context);
    if (lock.isLockedOut && !lock.needsMigration) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final LockResult result;
      if (lock.needsMigration) {
        result = await lock.completeMigration(_password.text, _confirm.text);
      } else {
        result = await lock.submitPassword(_password.text);
      }
      if (!mounted) return;
      if (result != LockResult.ok) {
        setState(() {
          _error = messageForLockResult(
            result,
            lockout: lock.lockoutRemaining,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    final lock = LockScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await lock.declineMigration();
      if (!mounted) return;
      if (result != LockResult.ok) {
        setState(() => _error = messageForLockResult(result));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = LockScope.of(context);
    final text = Theme.of(context).textTheme;
    final waiting = !lock.needsMigration && lock.lockoutRemaining > Duration.zero;
    final migrating = lock.needsMigration;
    final showForm = !lock.storageFailed && (!migrating || lock.migrationReady);
    // The cover sits beside the Router (MaterialApp.builder wraps the
    // router), so a BackButtonListener here cannot see it. The overlay
    // still eats taps. A system back may pop a route underneath; the
    // cover stays up until unlock, so that route is not usable.
    return Material(
        color: AppColors.background,
        child: GlassBackground(
          child: AppFrame(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandMark(),
                      const SizedBox(height: 18),
                      Text(
                        migrating && lock.migrationReady
                            ? '設定密碼鎖'
                            : 'Full 記帳已鎖定',
                        style: text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle(lock),
                        style: text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      if (lock.storageFailed) ...[
                        const SizedBox(height: 18),
                        Text(
                          lockStorageFailedMessage,
                          key: const Key('lock-error'),
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.expense,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _button(
                          key: const Key('lock-retry'),
                          label: '重試',
                          onPressed: _busy
                              ? null
                              : () => LockScope.of(context).bootstrap(),
                        ),
                      ],
                      if (waiting) ...[
                        const SizedBox(height: 16),
                        Text(
                          lockoutMessage(lock.lockoutRemaining),
                          key: const Key('lock-delay'),
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.expense,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (showForm) ...[
                        const SizedBox(height: 18),
                        _field(
                          controller: _password,
                          fieldKey: const Key('lock-password'),
                          label: migrating ? '新密碼' : '密碼',
                          enabled: !_busy && !waiting,
                          onSubmitted: (_) {
                            if (!migrating) _submit();
                          },
                        ),
                        if (migrating) ...[
                          const SizedBox(height: 10),
                          _field(
                            controller: _confirm,
                            fieldKey: const Key('lock-confirm'),
                            label: '再輸入一次',
                            enabled: !_busy && !waiting,
                            onSubmitted: (_) => _submit(),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            key: const Key('lock-error'),
                            style: text.bodySmall?.copyWith(
                              color: AppColors.expense,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _button(
                          key: const Key('lock-unlock'),
                          label: migrating ? '設定密碼' : '解鎖',
                          onPressed: _busy || waiting ? null : _submit,
                          busy: _busy,
                        ),
                        if (migrating) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            key: const Key('lock-decline'),
                            onPressed: _busy ? null : _decline,
                            child: const Text('不使用密碼鎖'),
                          ),
                        ],
                      ],
                      if (!lock.storageFailed &&
                          migrating &&
                          !lock.migrationReady) ...[
                        const SizedBox(height: 16),
                        _button(
                          key: const Key('lock-device-auth'),
                          label: '使用 Face ID、指紋或裝置密碼',
                          onPressed: _busy
                              ? null
                              : () => LockScope.of(context).unlock(),
                        ),
                      ],
                      if (!lock.storageFailed &&
                          lock.passwordEnabled &&
                          lock.biometricsEnabled) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          key: const Key('lock-biometric'),
                          onPressed: _busy
                              ? null
                              : () => LockScope.of(context).unlock(),
                          child: const Text('使用 Face ID'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }

  String _subtitle(LockController lock) {
    if (lock.storageFailed) return '鎖定設定暫時讀不到，帳本先保持蓋住。';
    if (lock.needsMigration && !lock.migrationReady) {
      return '舊版只用 Face ID。請先用 Face ID、指紋或裝置密碼驗證，再設定本機密碼。';
    }
    if (lock.needsMigration && lock.migrationReady) {
      return '請設定至少 4 個字的密碼。不使用密碼鎖會關閉舊的 Face ID 鎖定。';
    }
    if (lock.biometricsEnabled) {
      return '生物辨識失敗或取消時，改輸入密碼。';
    }
    return '輸入密碼解鎖';
  }

  Widget _field({
    required TextEditingController controller,
    required Key fieldKey,
    required String label,
    required bool enabled,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      // The IME must not learn the password.
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.sheet,
      ),
    );
  }

  Widget _button({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
    bool busy = false,
  }) {
    return FilledButton(
      key: key,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.sage,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
