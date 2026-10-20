import 'package:flutter/material.dart';
import 'package:full_jizhang/theme.dart';

class BootPage extends StatelessWidget {
  const BootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassBackground(
      child: Center(
        child: Text(
          '載入中…',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ),
    );
  }
}
