import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/pages/settings/password_form.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:go_router/go_router.dart';

/// Settings for the on-device ledger.
///
/// Book switching, opening, categories, and backup are the same jobs as the
/// cloud app. The lock rows are local-only. 密碼鎖 stores a salted slow
/// hash; Face ID is a shortcut that stays disabled until that password
/// exists, and turning the password off turns Face ID off with it. There
/// is no account and no logout.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _error;
  bool _busy = false;

  Future<void> _switchBook() async {
    final books = BookScope.of(context);
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final book in books.activeBooks)
                ListTile(
                  key: Key('settings-switch-${book.id}'),
                  title: Text(book.name),
                  trailing: book.id == books.current?.id
                      ? const Icon(Icons.check_rounded, color: AppColors.sageDark)
                      : null,
                  onTap: () => Navigator.pop(context, book.id),
                ),
              if (books.activeBooks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('沒有可切換的帳本'),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || id == null || id == books.current?.id) return;
    try {
      await books.select(id);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  /// Turns 密碼鎖 on or off.
  ///
  /// On asks for a new password and a confirmation. Off asks for the
  /// current password. The switch reads [LockController.passwordEnabled],
  /// so a cancel, a mismatch, a short password, or a wrong current
  /// password leaves it where it was. The controller is the rule; this
  /// method only shows the dialog and the message.
  Future<void> _togglePassword(bool value) async {
    if (_busy) return;
    final lock = LockScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (value) {
        final form = await showPasswordForm(
          context,
          mode: PasswordFormMode.enable,
        );
        if (!mounted || form == null) return;
        final result = await lock.enablePassword(form.next, form.confirmation);
        if (!mounted) return;
        _showLockResult(lock, result);
      } else {
        final form = await showPasswordForm(
          context,
          mode: PasswordFormMode.disable,
        );
        if (!mounted || form == null) return;
        final result = await lock.disablePassword(form.current);
        if (!mounted) return;
        _showLockResult(lock, result);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Replaces the hash. Current password first, then the new pair.
  Future<void> _changePassword() async {
    if (_busy) return;
    final lock = LockScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final form = await showPasswordForm(
        context,
        mode: PasswordFormMode.change,
      );
      if (!mounted || form == null) return;
      final result = await lock.changePassword(
        current: form.current,
        next: form.next,
        confirmation: form.confirmation,
      );
      if (!mounted) return;
      _showLockResult(lock, result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Face ID switch. Disabled in the tree when the password lock is off;
  /// this method repeats that rule so a direct call cannot bypass it.
  Future<void> _toggleBiometric(bool value) async {
    if (_busy) return;
    final lock = LockScope.of(context);
    if (!lock.passwordEnabled) {
      setState(() => _error = biometricNeedsPasswordMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await lock.setBiometrics(value);
      if (!mounted) return;
      if (result != LockResult.ok) {
        setState(() {
          _error = value
              ? biometricFailedMessage
              : messageForLockResult(result, lockout: lock.lockoutRemaining);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showLockResult(LockController lock, LockResult result) {
    final message = messageForLockResult(
      result,
      lockout: lock.lockoutRemaining,
    );
    if (message == null) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final books = BookScope.of(context);
    final lock = LockScope.of(context);
    final current = books.current?.name;
    final names = books.activeBooks.map((book) => book.name).join(' · ');
    return PageScroll(
      children: [
        Text('設定', style: text.titleLarge),
        const SizedBox(height: 12),
        _Group(
          children: [
            _SettingsRow(
              rowKey: const Key('settings-books'),
              icon: Icons.menu_book_outlined,
              title: '帳本管理',
              subtitle: current == null ? '尚未建立' : '目前：$current',
              onTap: () => context.push('/settings/books'),
            ),
            _SettingsRow(
              rowKey: const Key('settings-switch'),
              icon: Icons.swap_horiz_rounded,
              title: '切換帳本',
              subtitle: names.isEmpty ? '尚未建立' : names,
              onTap: _switchBook,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Group(
          children: [
            _SettingsRow(
              rowKey: const Key('settings-opening'),
              icon: Icons.flag_outlined,
              title: '開始開帳',
              subtitle: '選開帳日→帳戶餘額→現倉→預覽儲存',
              onTap: () => context.push('/opening'),
            ),
            _SettingsRow(
              rowKey: const Key('settings-categories'),
              icon: Icons.category_outlined,
              title: '分類管理',
              subtitle: '支出 · 收入',
              onTap: () => context.push('/settings/categories'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Group(
          children: [
            _SettingsRow(
              rowKey: const Key('settings-backup'),
              icon: Icons.cloud_upload_outlined,
              title: '備份與還原',
              subtitle: '匯出／匯入 JSON',
              onTap: () => context.push('/settings/backup'),
            ),
            _SwitchRow(
              icon: Icons.lock_outline,
              title: '密碼鎖',
              subtitle: '至少 4 個字。只存加鹽的慢雜湊，不存明文。',
              switchKey: const Key('settings-lock'),
              value: lock.passwordEnabled,
              onChanged: _busy ? null : _togglePassword,
            ),
            if (lock.passwordEnabled)
              _SettingsRow(
                rowKey: const Key('settings-change-password'),
                icon: Icons.key_outlined,
                title: '變更密碼',
                subtitle: '需要目前密碼',
                enabled: !_busy,
                onTap: _busy ? null : _changePassword,
              ),
            _SwitchRow(
              icon: Icons.fingerprint,
              title: 'Face ID／生物辨識',
              subtitle: lock.passwordEnabled
                  ? '解鎖時先試 Face ID／指紋，失敗再輸入密碼。'
                  : biometricNeedsPasswordMessage,
              subtitleKey: const Key('settings-biometric-hint'),
              switchKey: const Key('settings-biometric'),
              value: lock.biometricsEnabled,
              // Rule: the control is inert until 密碼鎖 is on. The hint
              // above is the explanation. Turning the password off clears
              // the flag, so this value drops with it.
              onChanged: _busy || !lock.passwordEnabled
                  ? null
                  : _toggleBiometric,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Group(
          children: [
            // Opens the shortcut setup. Recording still waits for a confirm
            // on the import sheet; this row does not write a ledger row.
            _SettingsRow(
              rowKey: const Key('settings-auto-record'),
              icon: Icons.contactless_outlined,
              title: '自動記帳',
              subtitle: 'Apple Pay 付款後帶入',
              onTap: () => context.push('/settings/auto-record'),
            ),
            const _SettingsRow(
              rowKey: Key('settings-disabled'),
              icon: Icons.sync_disabled_rounded,
              title: '銀行自動同步',
              subtitle: '這個版本沒有',
              enabled: false,
            ),
          ],
        ),
        ErrorLine(_error, lineKey: const Key('settings-error')),
        const SizedBox(height: 8),
        const Text(
          '新帳本可直接記帳，開帳為選填。多本帳本各自獨立開帳日。資料只存在這台裝置。',
          key: Key('settings-hint'),
          style: TextStyle(
            fontSize: 11,
            color: AppColors.secondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// A settings row with a switch instead of a chevron.
///
/// Purpose: 密碼鎖 and Face ID share one layout. [onChanged] null disables
/// the switch (Face ID while the password lock is off, or while a hash
/// is still running).
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.switchKey,
    required this.value,
    required this.onChanged,
    this.subtitleKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Key switchKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? subtitleKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0x248FB09F),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: AppColors.sageDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  key: subtitleKey,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            activeThumbColor: AppColors.sageDark,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0x1A3C3C43)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.rowKey,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Key? rowKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.ink;
    const iconColor = AppColors.sageDark;
    const iconBg = Color(0x248FB09F);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        key: rowKey,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (enabled)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
