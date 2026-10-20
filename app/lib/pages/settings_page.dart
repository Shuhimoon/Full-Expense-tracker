import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final email = AuthScope.of(context).user?.email;
    return ColoredBox(
      color: AppColors.sheet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
        children: [
          Text('設定', style: text.titleLarge),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(email, style: text.bodySmall),
          ],
          const SizedBox(height: 18),
          const _Row(
            icon: Icons.menu_book_outlined,
            title: '帳本管理',
            subtitle: '即將推出',
          ),
          const _Row(
            icon: Icons.swap_horiz_rounded,
            title: '切換帳本',
            subtitle: '即將推出',
          ),
          const _Row(
            icon: Icons.edit_calendar_outlined,
            title: '開始開帳',
            subtitle: '選開帳日 → 帳戶餘額 → 現倉 → 鎖定',
          ),
          const _Row(
            icon: Icons.category_outlined,
            title: '分類管理',
            subtitle: '支出 · 收入',
          ),
          const _Row(
            icon: Icons.cloud_outlined,
            title: '備份與還原',
            subtitle: '匯出／匯入 JSON',
          ),
          const SizedBox(height: 8),
          Material(
            color: AppColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.line),
            ),
            child: InkWell(
              key: const Key('logout'),
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: _busy ? null : _logout,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.expenseWash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.expense,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _busy ? '請稍候…' : '登出',
                      style: text.titleMedium?.copyWith(
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('settings-error'),
              style: text.bodySmall?.copyWith(color: AppColors.expense),
            ),
          ],
          const SizedBox(height: 16),
          Text('開帳後才可記一筆與看分析。多本帳本各自獨立開帳日。', style: text.bodySmall),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.sageWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.sageDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
