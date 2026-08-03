import 'package:flutter/material.dart';

class NotelyBackground extends StatelessWidget {
  const NotelyBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _NotelyBackgroundPainter(dark: dark),
      size: Size.infinite,
    );
  }
}

class _NotelyBackgroundPainter extends CustomPainter {
  final bool dark;

  _NotelyBackgroundPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = dark ? const Color(0xFF0E0B14) : const Color(0xFFFAF8F5);
    canvas.drawRect(Offset.zero & size, base);

    if (dark) {
      _blob(canvas, size, Offset(size.width * 0.85, size.height * 0.10), size.width * 0.85, const Color(0x3D7C5CF5));
      _blob(canvas, size, Offset(size.width * 0.05, size.height * 0.45), size.width * 0.7, const Color(0x2B4C1D95));
      _blob(canvas, size, Offset(size.width * 0.55, size.height * 0.98), size.width * 0.75, const Color(0x24312E81));
    } else {
      _blob(canvas, size, Offset(size.width * 0.85, size.height * 0.08), size.width * 0.85, const Color(0x30A78BFA));
      _blob(canvas, size, Offset(size.width * 0.02, size.height * 0.42), size.width * 0.7, const Color(0x2BF6D5FE));
      _blob(canvas, size, Offset(size.width * 0.55, size.height * 0.98), size.width * 0.75, const Color(0x26FDE8C8));
    }
  }

  void _blob(Canvas canvas, Size size, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_NotelyBackgroundPainter oldDelegate) => oldDelegate.dark != dark;
}
