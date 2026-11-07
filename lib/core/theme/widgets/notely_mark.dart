import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The Notely logo: a clipped note on two loose notes. [progress] runs the
/// build-up animation from 0 (nothing drawn) to 1 (the finished mark), so the
/// same painter serves the splash animation and every static use.
class NotelyMark extends StatelessWidget {
  final double size;
  final double progress;

  const NotelyMark({super.key, this.size = 96, this.progress = 1});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Notely',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: NotelyMarkPainter(progress: progress, colors: dark ? NotelyMarkColors.dark : NotelyMarkColors.light),
      ),
    );
  }
}

@immutable
class NotelyMarkColors {
  final Color outline;
  final Color writing;
  final Color page;
  final Color backLeft;
  final Color backRight;
  final Color clip;

  const NotelyMarkColors({
    required this.outline,
    required this.writing,
    required this.page,
    required this.backLeft,
    required this.backRight,
    required this.clip,
  });

  static const light = NotelyMarkColors(
    outline: Color(0xFF1F1B16),
    writing: Color(0xFF2F4AA0),
    page: Color(0xFFFFFFFF),
    backLeft: Color(0xFFAEBBE0),
    backRight: Color(0xFF7F93D1),
    clip: Color(0xFF8FA6E8),
  );

  static const dark = NotelyMarkColors(
    outline: Color(0xFF0E0D0C),
    writing: Color(0xFF2F4AA0),
    page: Color(0xFFECE8E1),
    backLeft: Color(0xFFAEBBE0),
    backRight: Color(0xFF7F93D1),
    clip: Color(0xFF8FA6E8),
  );
}

class NotelyMarkPainter extends CustomPainter {
  final double progress;
  final NotelyMarkColors colors;

  NotelyMarkPainter({required this.progress, required this.colors});

  // Drawn in a 512-unit space (the same geometry as the app icon), inside a
  // 520-unit box so the outline strokes aren't clipped.
  static const double _box = 520;
  static const Offset _origin = Offset(4, 8);
  static const double _stroke = 22;

  static const _backRight = [Offset(215, 183), Offset(500, 213), Offset(470, 500), Offset(185, 470)];
  static const _backLeft = [Offset(12, 210), Offset(287, 125), Offset(370, 390), Offset(95, 475)];
  static const _lines = [
    (Offset(218, 143), Offset(328, 143)),
    (Offset(167, 187), Offset(378, 187)),
    (Offset(167, 233), Offset(238, 233)),
    (Offset(270, 233), Offset(378, 233)),
    (Offset(167, 277), Offset(378, 277)),
  ];

  // Each part's share of the timeline (start, end), as fractions of progress.
  static const _front = (0.0, 0.42);
  static const _fanLeft = (0.19, 0.64);
  static const _fanRight = (0.23, 0.68);
  static const _clipIn = (0.38, 0.72);
  static const _lineStarts = [0.53, 0.61, 0.68, 0.73, 0.79];
  static const _lineLength = 0.21;

  static double _phase((double, double) span, double t) => ((t - span.$1) / (span.$2 - span.$1)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.scale(size.width / _box, size.height / _box);
    canvas.translate(_origin.dx, _origin.dy);

    final outline = Paint()
      ..color = colors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // The loose notes fan out from behind the top note.
    _drawLoose(
      canvas,
      _backRight,
      colors.backRight,
      outline,
      const Offset(-70, -30),
      -6,
      Curves.easeOutCubic.transform(_phase(_fanRight, t)),
    );
    _drawLoose(
      canvas,
      _backLeft,
      colors.backLeft,
      outline,
      const Offset(70, -30),
      17,
      Curves.easeOutCubic.transform(_phase(_fanLeft, t)),
    );

    // The top note drops in.
    final f = Curves.easeOutCubic.transform(_phase(_front, t));
    if (f > 0) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, f));
      canvas.translate(270, 197);
      canvas.scale(lerpDouble(0.94, 1, f)!);
      canvas.translate(-270, -197 - 26 * (1 - f));
      canvas.drawRRect(RRect.fromLTRBR(125, 50, 415, 345, const Radius.circular(12)), Paint()..color = colors.page);
      canvas.drawPath(_frontOutline(), outline);
      canvas.restore();
    }

    // The clip snaps on with a small overshoot.
    final c = _phase(_clipIn, t);
    if (c > 0) {
      final dy = -60 * (1 - Curves.easeOutBack.transform(c));
      final clip = RRect.fromLTRBR(247, 8 + dy, 299, 98 + dy, const Radius.circular(10));
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, math.min(1, c * 2)));
      canvas.drawRRect(clip, Paint()..color = colors.clip);
      canvas.drawRRect(clip, outline);
      canvas.restore();
    }

    // The writing appears line by line, left to right.
    final ink = Paint()
      ..color = colors.writing
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _lines.length; i++) {
      final p = Curves.easeInOutCubic.transform(((t - _lineStarts[i]) / _lineLength).clamp(0.0, 1.0));
      if (p <= 0) continue;
      final (a, b) = _lines[i];
      canvas.drawLine(a, Offset.lerp(a, b, p)!, ink);
    }
    canvas.restore();
  }

  void _drawLoose(
    Canvas canvas,
    List<Offset> corners,
    Color fill,
    Paint outline,
    Offset from,
    double fromDegrees,
    double p,
  ) {
    if (p <= 0) return;
    final center = corners.reduce((a, b) => a + b) / 4;
    final path = Path()..addPolygon(corners, true);
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, p));
    canvas.translate(center.dx + from.dx * (1 - p), center.dy + from.dy * (1 - p));
    canvas.rotate(fromDegrees * (1 - p) * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, outline);
    canvas.restore();
  }

  // The top note's outline, with the opening beside the clip.
  static Path _frontOutline() {
    const r = Radius.circular(12);
    return Path()
      ..moveTo(245, 50)
      ..lineTo(137, 50)
      ..arcToPoint(const Offset(125, 62), radius: r, clockwise: false)
      ..lineTo(125, 333)
      ..arcToPoint(const Offset(137, 345), radius: r, clockwise: false)
      ..lineTo(403, 345)
      ..arcToPoint(const Offset(415, 333), radius: r, clockwise: false)
      ..lineTo(415, 62)
      ..arcToPoint(const Offset(403, 50), radius: r, clockwise: false)
      ..lineTo(385, 50)
      ..moveTo(355, 50)
      ..lineTo(300, 50);
  }

  @override
  bool shouldRepaint(NotelyMarkPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.colors != colors;
}
