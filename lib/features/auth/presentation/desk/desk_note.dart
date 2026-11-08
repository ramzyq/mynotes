import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/widgets/notely_mark.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_layout.dart';

/// Ink on the notes: the logo's writing blue.
const deskInk = Color(0xFF22357A);

/// The paper colours of the three notes, matching the logo.
Color deskNoteColor(DeskNoteRole role) => switch (role) {
      DeskNoteRole.left => const Color(0xFFADBBE0),
      DeskNoteRole.right => const Color(0xFF8095CF),
      DeskNoteRole.middle => const Color(0xFFFDFBF7),
    };

/// The notes' outline. In dark mode it's a warm grey rather than the logo's
/// near-black, so the notes keep a crisp edge against the dark page.
Color deskOutline(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5E584F) : NotelyMarkColors.light.outline;

/// The logo's own outline, which the notes blend into as they become it.
Color logoOutline(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? NotelyMarkColors.dark.outline : NotelyMarkColors.light.outline;

/// One note as drawn at a moment in time: [flip] turns it over (0 face-up,
/// 1 face-down), [contentOpacity] fades its writing, and [stroke] and
/// [radius] let it become the logo's heavier outline.
class DeskNoteFace extends StatelessWidget {
  const DeskNoteFace({
    super.key,
    required this.role,
    this.content,
    this.flip = 0,
    this.contentOpacity = 1,
    this.stroke = 3,
    this.outline,
    this.radius = 12,
    this.shadow = true,
  });

  final DeskNoteRole role;
  final Widget? content;
  final double flip;
  final double contentOpacity;
  final double stroke;

  /// Overrides the outline colour (the sign-in moment blends it into the logo's).
  final Color? outline;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final outline = this.outline ?? deskOutline(context);
    final showBack = flip > 0.5;
    final face = Container(
      decoration: BoxDecoration(
        color: deskNoteColor(role),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: outline, width: stroke),
        boxShadow: shadow ? const [BoxShadow(color: Color(0x38000000), blurRadius: 34, offset: Offset(0, 14))] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0, radius - stroke)),
        child: showBack
            ? CustomPaint(painter: _BackPainter(deskNoteColor(role)), child: const Center(child: _LockBadge()))
            : Opacity(opacity: contentOpacity.clamp(0, 1), child: content ?? const SizedBox.expand()),
      ),
    );
    final angle = math.pi * flip;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle),
      // The back is drawn mirrored so it reads the right way round.
      child: showBack ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: face) : face,
    );
  }
}

/// A note that turns over when [faceDown] changes, after [delay], so a row
/// of them turns one after another.
class DeskNote extends StatefulWidget {
  const DeskNote({super.key, required this.role, this.content, this.faceDown = false, this.delay = Duration.zero});

  final DeskNoteRole role;
  final Widget? content;
  final bool faceDown;
  final Duration delay;

  @override
  State<DeskNote> createState() => _DeskNoteState();
}

class _DeskNoteState extends State<DeskNote> with SingleTickerProviderStateMixin {
  static const _turn = Duration(milliseconds: 900);
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: _turn + widget.delay,
    value: widget.faceDown ? 1 : 0,
  );

  // The delay is the first stretch of the run, so no timers are involved.
  late final Curve _curve = Interval(
    widget.delay.inMicroseconds / (_turn + widget.delay).inMicroseconds,
    1,
    curve: const Cubic(0.45, 0.05, 0.2, 1),
  );

  @override
  void didUpdateWidget(DeskNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.faceDown == oldWidget.faceDown) return;
    if (NotelyMotion.reduced(context)) {
      _flip.value = widget.faceDown ? 1 : 0;
    } else {
      widget.faceDown ? _flip.forward() : _flip.reverse();
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) => DeskNoteFace(
        role: widget.role,
        content: widget.content,
        flip: _curve.transform(_flip.value),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  _BackPainter(this.base);
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final stripe = Paint()
      ..color = Color.lerp(base, const Color(0xFF22357A), 0.08)!
      ..strokeWidth = 10;
    for (double x = -size.height; x < size.width + size.height; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), stripe);
    }
  }

  @override
  bool shouldRepaint(_BackPainter oldDelegate) => oldDelegate.base != base;
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(color: Color(0xBF0D0C0B), shape: BoxShape.circle),
      child: const Icon(Icons.lock_outline, size: 15, color: Color(0xFFEFE9DE)),
    );
  }
}

/// The writing on a note: an italic line or two and some ruled lines.
class DeskNoteWriting extends StatelessWidget {
  const DeskNoteWriting({super.key, this.text, this.lines = const [1.0]});
  final String? text;
  final List<double> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text != null)
            Text(
              text!,
              maxLines: 3,
              overflow: TextOverflow.clip,
              style: const TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic, fontSize: 15, height: 1.2, color: deskInk),
            ),
          for (final w in lines)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: FractionallySizedBox(
                widthFactor: w,
                child: Container(height: 5, decoration: BoxDecoration(color: deskInk.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(3))),
              ),
            ),
        ],
      ),
    );
  }
}

/// What's written on the three notes on the sign-in screens. Made up, on
/// purpose: nobody's real notes appear before they've signed in.
abstract final class DeskWriting {
  static const left = DeskNoteWriting(text: "Trip to Accra: flights, Aunty's address");
  static const right = DeskNoteWriting(text: 'Book club, ch. 7 thoughts', lines: [1, 1]);
  static const ideas = DeskNoteWriting(text: 'Ideas', lines: [1, 0.6]);
}
