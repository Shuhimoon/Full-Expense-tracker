import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String? _error;

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthScope.of(context).logout();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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

  Future<void> _password() async {
    final submitted = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _PasswordDialog(),
    );
    if (submitted == null || !mounted) return;
    final (oldPassword, newPassword) = submitted;
    if (newPassword.length < 8) {
      setState(() => _error = '密碼至少 8 碼');
      return;
    }
    final api = AuthScope.of(context).api;
    try {
      await api.changePassword(oldPassword: oldPassword, newPassword: newPassword);
      if (mounted) setState(() => _error = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final email = AuthScope.of(context).user?.email ?? '';
    final books = BookScope.of(context);
    final current = books.current?.name;
    final names = books.activeBooks.map((book) => book.name).join(' · ');
    return PageScroll(
      children: [
        Text('設定', style: text.titleLarge),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(email, key: const Key('settings-email'), style: text.bodySmall),
        ],
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
            _SettingsRow(
              rowKey: const Key('settings-password'),
              icon: Icons.lock_outline_rounded,
              title: '變更密碼',
              subtitle: '至少 8 碼',
              onTap: _password,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Group(
          children: [
            const _SettingsRow(
              rowKey: Key('settings-disabled'),
              icon: Icons.sync_disabled_rounded,
              title: '銀行自動同步',
              subtitle: '這個版本沒有',
              enabled: false,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Group(
          children: [
            _SettingsRow(
              rowKey: const Key('logout'),
              icon: Icons.logout_rounded,
              title: _busy ? '請稍候…' : '登出',
              danger: true,
              onTap: _busy ? null : _logout,
            ),
          ],
        ),
        ErrorLine(_error, lineKey: const Key('settings-error')),
        const SizedBox(height: 8),
        const Text(
          '開帳後才可記一筆與看分析。多本帳本各自獨立開帳日。',
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

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('變更密碼'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('password-old'),
            controller: _old,
            obscureText: true,
            decoration: const InputDecoration(labelText: '目前密碼'),
          ),
          TextField(
            key: const Key('password-new'),
            controller: _new,
            obscureText: true,
            decoration: const InputDecoration(labelText: '新密碼'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('password-save'),
          onPressed: () => Navigator.pop(context, (_old.text, _new.text)),
          child: const Text('更新'),
        ),
      ],
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
    this.danger = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Key? rowKey;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.expense : AppColors.ink;
    final iconColor = danger ? AppColors.expense : AppColors.sageDark;
    final iconBg = danger ? AppColors.expenseWash : const Color(0x248FB09F);
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
              if (enabled && !danger)
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
