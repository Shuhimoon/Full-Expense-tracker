import 'package:flutter/material.dart';
import 'package:full_jizhang/theme.dart';
import 'package:go_router/go_router.dart';

class RecordPage extends StatelessWidget {
  const RecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassBackground(
      child: AppFrame(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Expanded(
              flex: 5,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  0,
                  10,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.sheet,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.sheet),
                      bottom: Radius.circular(AppRadius.sheet),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            key: const Key('record-close'),
                            tooltip: '關閉',
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        Text('記一筆', style: text.titleLarge),
                        const SizedBox(height: 8),
                        Text('支出、收入、轉帳與成交會出現在這裡。', style: text.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
