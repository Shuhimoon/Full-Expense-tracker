import 'package:flutter/material.dart';
import 'package:full_jizhang/theme.dart';
import 'package:go_router/go_router.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xC7FFFCFA),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0x08000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3C2814),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: children,
    );
    return ColoredBox(
      color: AppColors.sheet,
      child: onRefresh == null
          ? list
          : RefreshIndicator(
              color: AppColors.sageDark,
              onRefresh: onRefresh!,
              child: list,
            ),
    );
  }
}

class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key, this.lineKey});

  final String? message;
  final Key? lineKey;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message!,
        key: lineKey,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.expense,
        ),
      ),
    );
  }
}

class SubpageHeader extends StatelessWidget {
  const SubpageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('subpage-back'),
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
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );
  }
}
