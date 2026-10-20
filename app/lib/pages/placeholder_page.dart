import 'package:flutter/material.dart';
import 'package:full_jizhang/theme.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.sheet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        children: [
          Text(title, style: text.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: text.bodySmall),
        ],
      ),
    );
  }
}
