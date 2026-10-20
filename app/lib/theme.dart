import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full 記帳 iOS Glass palette.
abstract final class AppColors {
  static const background = Color(0xFFF2EFE8);
  static const sheet = Color(0xFFFFFCFA);
  static const card = Color(0xFFFFFCFA);
  static const sage = Color(0xFF8FB09F);
  static const sageDark = Color(0xFF5F8574);
  static const expense = Color(0xFF8B1A3A);
  static const ink = Color(0xFF1C1917);
  static const muted = Color(0xFF8A8178);
  static const faint = Color(0xFFB7AFA6);
  static const line = Color(0xFFE7E1D8);
  static const track = Color(0xFFE4DFD6);
  static const sageBlob = Color(0xFFD5E6DC);
  static const peachBlob = Color(0xFFF6DDD0);
  static const sageWash = Color(0xFFE7F0EA);
  static const expenseWash = Color(0xFFF8E8EC);
}

abstract final class AppRadius {
  static const sheet = 28.0;
  static const card = 16.0;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sage,
      primary: AppColors.sage,
      onPrimary: Colors.white,
      secondary: AppColors.sageDark,
      surface: AppColors.sheet,
      error: AppColors.expense,
    ),
  );
  final textTheme = GoogleFonts.notoSansTcTextTheme(base.textTheme).copyWith(
    headlineMedium: GoogleFonts.notoSansTc(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
      height: 1.15,
      letterSpacing: -0.4,
    ),
    titleLarge: GoogleFonts.notoSansTc(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
      height: 1.2,
    ),
    titleMedium: GoogleFonts.notoSansTc(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: GoogleFonts.notoSansTc(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    ),
    bodyMedium: GoogleFonts.notoSansTc(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    bodySmall: GoogleFonts.notoSansTc(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.muted,
    ),
    labelLarge: GoogleFonts.notoSansTc(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  );
  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: GoogleFonts.notoSansTcTextTheme(base.primaryTextTheme),
    splashColor: AppColors.sage.withValues(alpha: 0.16),
    highlightColor: AppColors.sage.withValues(alpha: 0.08),
  );
}

/// Cream field with large blurred sage and peach blobs.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: AppColors.background,
        child: Stack(
          children: [
            const _Blob(
              top: -130,
              right: -90,
              size: 360,
              color: AppColors.sageBlob,
            ),
            const _Blob(
              top: 240,
              left: -150,
              size: 320,
              color: AppColors.peachBlob,
            ),
            const _Blob(
              bottom: -80,
              right: -20,
              size: 280,
              color: Color(0xFFE9D5C8),
            ),
            const _Blob(
              bottom: 160,
              left: -40,
              size: 180,
              color: Color(0xFFDCE8E1),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.color,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  final double size;
  final Color color;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 72, sigmaY: 72),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

/// Centers content in a phone-width column on wide web windows.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0, 480).toDouble();
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding:
                padding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: child,
          ),
        ),
      ),
    );
  }
}
