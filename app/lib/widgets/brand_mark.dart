import 'package:flutter/material.dart';
import 'package:full_jizhang/theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x338FB09F),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sage = Paint()
      ..color = AppColors.sageDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rose = Paint()
      ..color = const Color(0xFFD7A3A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = AppColors.sage;
    final gold = Paint()..color = const Color(0xFFE4C27A);
    final book = Paint()..color = const Color(0xFFF0D2CB);

    final monogram = Path()
      ..moveTo(w * 0.42, h * 0.24)
      ..cubicTo(w * 0.68, h * 0.16, w * 0.74, h * 0.46, w * 0.50, h * 0.52)
      ..cubicTo(w * 0.30, h * 0.58, w * 0.32, h * 0.78, w * 0.55, h * 0.72);
    canvas.drawPath(monogram, sage);

    final accent = Path()
      ..moveTo(w * 0.48, h * 0.22)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.64, h * 0.58, w * 0.44, h * 0.50);
    canvas.drawPath(accent, rose);

    final leafPath = Path()
      ..moveTo(w * 0.34, h * 0.40)
      ..quadraticBezierTo(w * 0.20, h * 0.28, w * 0.34, h * 0.24)
      ..quadraticBezierTo(w * 0.30, h * 0.34, w * 0.34, h * 0.40);
    canvas.drawPath(leafPath, leaf);

    canvas.drawCircle(Offset(w * 0.30, h * 0.70), 6.5, gold);
    canvas.drawCircle(
      Offset(w * 0.40, h * 0.76),
      4.5,
      Paint()..color = const Color(0xFFD7B56A),
    );

    final bookRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.58, h * 0.62, 18, 13),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(bookRect, book);
    canvas.drawLine(
      Offset(w * 0.67, h * 0.64),
      Offset(w * 0.67, h * 0.73),
      Paint()
        ..color = AppColors.sageDark
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
