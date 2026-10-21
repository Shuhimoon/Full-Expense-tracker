import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:go_router/go_router.dart';

/// Settings for the on-device ledger.
///
/// Book switching, opening, categories, and backup are the same jobs as the
/// cloud app. The lock row is local-only: it calls [LockController.setEnabled],
/// which prompts for Face ID, fingerprint, or the device passcode and stays
/// off if that prompt fails (fail closed). There is no account and no logout.
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

  /// Turns the app lock on or off.
  ///
  /// Enabling requires a successful [LockController.setEnabled] prompt.
  /// If the controller stays disabled, the row shows 「無法使用裝置驗證」 and
  /// the switch snaps back because it reads [LockController.enabled].
  Future<void> _toggleLock(bool value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await LockScope.of(context).setEnabled(value);
      if (!mounted) return;
      if (value && !LockScope.of(context).enabled) {
        setState(() => _error = '無法使用裝置驗證');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '無法使用裝置驗證');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            Padding(
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
                    child: const Icon(
                      Icons.fingerprint,
                      size: 18,
                      color: AppColors.sageDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '應用程式鎖定',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Face ID／生物辨識／裝置密碼',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('settings-lock'),
                    value: lock.enabled,
                    activeThumbColor: AppColors.sageDark,
                    onChanged: _busy ? null : _toggleLock,
                  ),
                ],
              ),
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
