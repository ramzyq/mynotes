import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_layout.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_note.dart';

const _paper = Color(0xFFFDFBF7);
const _accentInk = Color(0xFF2F4AA0);

/// Lays a scene piece out on the desk, centred, [down] below the top of the
/// notes.
class _OnDesk extends StatelessWidget {
  const _OnDesk({required this.down, required this.width, required this.child});
  final double down;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final layout = DeskLayout(box.biggest, top: MediaQuery.paddingOf(context).top + 8);
      final s = layout.scale;
      return Stack(children: [
        Positioned(
          top: layout.top + down * s,
          left: (box.maxWidth - width * s) / 2,
          width: width * s,
          child: IgnorePointer(child: child),
        ),
      ]);
    });
  }
}

BoxDecoration _noteBox(BuildContext context) => BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: deskOutline(context), width: 3),
      boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 36, offset: Offset(0, 16))],
    );

/// Locked out, step 2: a note carrying the reset key rises out of the stack
/// and waits while the email arrives.
class KeyNoteScene extends StatefulWidget {
  const KeyNoteScene({super.key});

  @override
  State<KeyNoteScene> createState() => _KeyNoteSceneState();
}

class _KeyNoteSceneState extends State<KeyNoteScene> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    NotelyMotion.ambient(context) ? _wiggle.repeat() : _wiggle.stop();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OnDesk(
      down: 104,
      width: 176,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: NotelyMotion.of(context, const Duration(milliseconds: 900)),
        curve: const Cubic(0.2, 0.9, 0.25, 1.15),
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 300 * (1 - t)),
            child: Transform.rotate(angle: (-10 + 7 * t) * math.pi / 180, child: child),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: _noteBox(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                AnimatedBuilder(
                  animation: _wiggle,
                  builder: (context, child) => Transform.rotate(angle: _wiggleAngle(_wiggle.value), child: child),
                  child: const Icon(Icons.key_rounded, size: 26, color: _accentInk),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Your reset key',
                    style: TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic, fontSize: 19, color: deskInk),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'notely.app/reset?oobCode=…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: Color(0xFF5E554A)),
              ),
              const SizedBox(height: 5),
              Container(height: 2, decoration: BoxDecoration(color: _accentInk.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(1))),
            ],
          ),
        ),
      ),
    );
  }

  /// A small turn now and then, like a key trying the lock.
  static double _wiggleAngle(double t) {
    if (t < 0.7) return 0;
    final p = (t - 0.7) / 0.3;
    return math.sin(p * math.pi * 3) * (1 - p) * 0.25;
  }
}

/// Locked out, step 3: the old notes have cleared and a fresh note labelled
/// "New password" drops in from the top. Each character typed is inked onto
/// it as a dot; it's stamped "Matches" when the two fields agree.
class NewPasswordNoteScene extends StatelessWidget {
  const NewPasswordNoteScene({super.key, required this.length, required this.matches});

  final int length;
  final bool matches;

  @override
  Widget build(BuildContext context) {
    return _OnDesk(
      down: 96,
      width: 204,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: NotelyMotion.of(context, const Duration(milliseconds: 1300)),
        // Waits while the old notes clear, then lands with a small bounce.
        curve: const Interval(0.27, 1, curve: Cubic(0.3, 1.25, 0.4, 1)),
        builder: (context, t, child) => Transform.translate(
          offset: Offset(0, -380 * (1 - t)),
          child: Transform.rotate(angle: (10 - 12 * t) * math.pi / 180, child: child),
        ),
        child: Container(
          height: 112,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
          decoration: _noteBox(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Text(
                'New password',
                style: TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic, fontSize: 17, color: deskInk),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedScale(
                  scale: matches ? 1 : 0.6,
                  duration: const Duration(milliseconds: 350),
                  curve: const Cubic(0.2, 0.9, 0.3, 1.6),
                  child: AnimatedOpacity(
                    opacity: matches ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Transform.rotate(
                      angle: -8 * math.pi / 180,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF16A34A), width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Matches',
                          style: TextStyle(fontFamily: 'Geist', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 34,
                height: 22,
                child: ClipRect(
                  child: Row(children: [
                    for (var i = 0; i < math.min(length, 14); i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(i),
                          tween: Tween(begin: 0, end: 1),
                          duration: NotelyMotion.of(context, const Duration(milliseconds: 350)),
                          curve: const Cubic(0.2, 0.9, 0.3, 1.4),
                          builder: (context, t, child) => Transform.translate(
                            offset: Offset(0, -6 * (1 - t)),
                            child: Transform.scale(scale: t.clamp(0.0, 1.4), child: child),
                          ),
                          child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: _accentInk, shape: BoxShape.circle)),
                        ),
                      ),
                    Container(width: 1.5, height: 18, color: _accentInk),
                  ]),
                ),
              ),
              Positioned(
                left: 0,
                right: 2,
                top: 62,
                child: Container(height: 2, decoration: BoxDecoration(color: deskInk.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(1))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verify email: a note slips into an envelope, the flap closes, and it
/// flies off toward the inbox; a sealed one settles back in its place.
class EnvelopeScene extends StatefulWidget {
  const EnvelopeScene({super.key});

  @override
  State<EnvelopeScene> createState() => EnvelopeSceneState();
}

class EnvelopeSceneState extends State<EnvelopeScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.value == 0 && !_c.isAnimating) play();
  }

  /// Sends the envelope (again).
  void play() {
    if (NotelyMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OnDesk(
      down: 70,
      width: 168,
      child: AspectRatio(
        aspectRatio: 168 / 160,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _EnvelopePainter(_c.value, deskOutline(context))),
        ),
      ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  _EnvelopePainter(this.t, this.outline);
  final double t;
  final Color outline;

  static double _span(double t, double a, double b, [Curve curve = Curves.easeInOutCubic]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 168;
    canvas.scale(k);
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color c) => Paint()..color = c;

    final slide = _span(t, 0.04, 0.3);
    final shut = _span(t, 0.28, 0.42);
    final fly = _span(t, 0.48, 0.72, Curves.easeInCubic);
    final settle = _span(t, 0.82, 1, Curves.easeOutCubic);

    void envelope({required double paper, required double flap}) {
      // Back, then the open flap behind the note.
      final back = RRect.fromLTRBR(4, 62, 164, 156, const Radius.circular(10));
      canvas.drawRRect(back, fill(const Color(0xFF8095CF)));
      canvas.drawRRect(back, stroke);
      if (flap < 0.5) {
        final open = Path()
          ..moveTo(4, 62)
          ..lineTo(84, 62 - 54 * (1 - flap * 2))
          ..lineTo(164, 62)
          ..close();
        canvas.drawPath(open, fill(const Color(0xFF6F88D6)));
        canvas.drawPath(open, stroke);
      }
      // The note, sliding down into the pocket.
      final dy = 64 * paper;
      final note = RRect.fromLTRBR(24, 4 + dy, 144, 90 + dy, const Radius.circular(8));
      canvas.drawRRect(note, fill(_paper));
      canvas.drawRRect(note, stroke);
      final ink = Paint()
        ..color = const Color(0x8022357A)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      for (final (y, x2) in const [(26.0, 128.0), (42.0, 104.0), (58.0, 120.0)]) {
        canvas.drawLine(Offset(40, y + dy), Offset(x2, y + dy), ink);
      }
      // The front pocket.
      final pocket = Path()
        ..moveTo(4, 62)
        ..lineTo(84, 112)
        ..lineTo(164, 62)
        ..lineTo(164, 146)
        ..quadraticBezierTo(164, 156, 154, 156)
        ..lineTo(14, 156)
        ..quadraticBezierTo(4, 156, 4, 146)
        ..close();
      canvas.drawPath(pocket, fill(const Color(0xFFADBBE0)));
      canvas.drawPath(pocket, stroke);
      // The flap folding down over it.
      if (flap >= 0.5) {
        final closed = Path()
          ..moveTo(4, 62)
          ..lineTo(84, 62 + 54 * ((flap - 0.5) * 2))
          ..lineTo(164, 62)
          ..close();
        canvas.drawPath(closed, fill(const Color(0xFF6F88D6)));
        canvas.drawPath(closed, stroke);
      }
    }

    if (fly < 1) {
      canvas.save();
      canvas.translate(84 + 150 * fly, 80 - 230 * fly);
      canvas.rotate(22 * math.pi / 180 * fly);
      canvas.scale(1 - 0.45 * fly);
      canvas.translate(-84, -80);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - fly));
      envelope(paper: slide, flap: shut);
      canvas.restore();
      canvas.restore();
    }
    if (settle > 0) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, settle));
      canvas.translate(0, 10 * (1 - settle));
      envelope(paper: 1, flap: 1);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EnvelopePainter oldDelegate) => oldDelegate.t != t || oldDelegate.outline != outline;
}

/// How strong a new password looks, 0 (empty) to 4.
int passwordStrength(String v, int minLength) {
  if (v.isEmpty) return 0;
  if (v.length < minLength) return 1;
  var s = 1;
  if (RegExp('[A-Z]').hasMatch(v) && RegExp('[a-z]').hasMatch(v)) s++;
  if (RegExp(r'\d').hasMatch(v)) s++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(v) || v.length >= 14) s++;
  return s;
}

/// The four-bar strength meter under a new password.
class StrengthMeter extends StatelessWidget {
  const StrengthMeter({super.key, required this.strength, required this.empty, required this.danger, required this.ok, required this.good});

  final int strength;
  final Color empty;
  final Color danger;
  final Color ok;
  final Color good;

  @override
  Widget build(BuildContext context) {
    final color = switch (strength) { 1 => danger, 2 => ok, _ => good };
    return Row(children: [
      for (var i = 0; i < 4; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            decoration: BoxDecoration(color: i < strength ? color : empty, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    ]);
  }
}
