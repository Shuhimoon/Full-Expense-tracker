import 'package:flutter/material.dart';
import 'package:full_jizhang/theme.dart';
import 'package:go_router/go_router.dart';

/// Opening wizard is the next milestone. This route only reserves the entry.
class OpeningStubPage extends StatelessWidget {
  const OpeningStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassBackground(
      child: AppFrame(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  key: const Key('opening-back'),
                  tooltip: '返回',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/settings');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: AppColors.sageDark,
                ),
                const SizedBox(height: 12),
                Text('開始開帳', style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '開帳精靈（選開帳日、帳戶餘額、現倉、預覽儲存）會在下一個里程碑完成。',
                  key: const Key('opening-stub'),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '現在可以先建立帳本並記日常收支。開帳日之前的日期不能記。',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
