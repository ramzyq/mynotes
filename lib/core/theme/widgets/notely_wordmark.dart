import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class NotelyWordmark extends StatelessWidget {
  final double size;

  const NotelyWordmark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size + 4,
          height: size + 4,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC4A7FF), Color(0xFF7C3AED)],
            ),
          ),
          child: CustomPaint(size: Size(size, size), painter: _NotelyNPainter()),
        ),
        const SizedBox(width: 7),
        Text('Notely', style: TextStyle(fontFamily: 'Geist', fontSize: size, fontWeight: FontWeight.w600, color: notely.text, letterSpacing: -0.4)),
      ],
    );
  }
}

class _NotelyNPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
