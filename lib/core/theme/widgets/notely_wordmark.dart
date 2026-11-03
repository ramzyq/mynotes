import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class NotelyWordmark extends StatelessWidget {
  final double size;

  const NotelyWordmark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    // Flat mark: the N stroke in ink, no tile, no gradient.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: Size(size + 4, size + 4), painter: _NotelyNPainter(color: notely.violet)),
        const SizedBox(width: 8),
        Text('Notely', style: TextStyle(fontFamily: 'Geist', fontSize: size, fontWeight: FontWeight.w600, color: notely.text)),
      ],
    );
  }
}

class _NotelyNPainter extends CustomPainter {
  final Color color;
  _NotelyNPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.71)
      ..lineTo(size.width * 0.29, size.height * 0.33)
      ..lineTo(size.width * 0.71, size.height * 0.71)
      ..lineTo(size.width * 0.71, size.height * 0.33);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NotelyNPainter oldDelegate) => oldDelegate.color != color;
}
