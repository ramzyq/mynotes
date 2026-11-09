import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_mark.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_layout.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_note.dart';

/// The moment after signing in or creating an account: the card sinks away,
/// the three notes slide into the Notely logo, the clip snaps on, "Notely"
/// rises underneath, and the screen behind (home, or verify email) is
/// revealed.
///
/// It runs in the root overlay, so it outlives the sign-in screen, which the
/// app replaces the moment the account is signed in.
void showLogoMoment(OverlayState overlay, {bool faceDown = false, Widget middle = DeskWriting.ideas, Rect? card, String? welcome}) {
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _LogoMoment(faceDown: faceDown, middle: middle, card: card, welcome: welcome, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

/// The on-screen box of the widget [key] is attached to, if it's laid out.
Rect? globalRectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _LogoMoment extends StatefulWidget {
  const _LogoMoment({required this.faceDown, required this.middle, required this.card, required this.welcome, required this.onDone});

  final bool faceDown;
  final Widget middle;
  final Rect? card;
  final String? welcome;
  final VoidCallback onDone;

  @override
  State<_LogoMoment> createState() => _LogoMomentState();
}

class _LogoMomentState extends State<_LogoMoment> with SingleTickerProviderStateMixin {
  // Milliseconds on the full timeline.
  static const _total = 3200;
  static const _travelEnd = 900;
  static const _markStart = 950;
  static const _markEnd = 1900;
  static const _clipSnap = 1150;
  static const _wordStart = 1700;
  static const _leaveStart = 2700;

  late final AnimationController _c;
  bool _reduced = false;
  bool _buzzed = false;
  bool _done = false;

  /// A tap jumps to the fade-out, for anyone who'd rather not wait.
  void _skip() {
    final leaveAt = _reduced ? 0.8 : _leaveStart / _total;
    if (_c.value < leaveAt) {
      _c.value = leaveAt;
      _c.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _c =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: _total),
          )
          ..addListener(_haptic)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && !_done) {
              _done = true;
              widget.onDone();
            }
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    _reduced = NotelyMotion.reduced(context);
    if (_reduced) {
      // Under reduce motion: the finished logo and name fade in and out.
      _c.duration = const Duration(milliseconds: 1600);
      NotelyHaptics.success();
      _buzzed = true;
    }
    _c.forward();
  }

  void _haptic() {
    if (!_buzzed && _ms >= _clipSnap) {
      _buzzed = true;
      NotelyHaptics.success();
    }
  }

  double get _ms => _c.value * _total;

  double _span(int from, int to, [Curve curve = Curves.linear]) => curve.transform(((_ms - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (_reduced) return _reducedFrame(context);
        final leave = _span(_leaveStart, _total, NotelyMotion.exit);
        return IgnorePointer(
          ignoring: leave > 0.5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: Opacity(
              opacity: 1 - leave,
              child: Material(
                color: notely.bg,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final layout = DeskLayout(box.biggest, top: MediaQuery.paddingOf(context).top + 8);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (widget.card != null) _ghostCard(notely),
                        // The notes stay solid under the logo as it fades in on
                        // top, so nothing shows through; then they go.
                        if (_ms < _markStart + 400) ...[for (final role in DeskNoteRole.values) _travellingNote(layout, role)],
                        _mark(layout),
                        _word(layout, notely),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The card the user just used, sinking away.
  Widget _ghostCard(NotelyTheme notely) {
    final t = _span(0, 450, NotelyMotion.exit);
    final rect = widget.card!;
    return Positioned.fromRect(
      rect: rect.shift(Offset(0, 50 * t)),
      child: Opacity(
        opacity: 1 - t,
        child: Container(
          decoration: BoxDecoration(
            color: notely.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: notely.border),
          ),
        ),
      ),
    );
  }

  Widget _travellingNote(DeskLayout layout, DeskNoteRole role) {
    final move = _span(0, _travelEnd, const Cubic(0.5, 0, 0.2, 1));
    final spot = DeskSpot.lerp(layout.desk(role), layout.logo(role), move);
    // Face-down notes turn back over on the way; the writing fades off.
    final flip = widget.faceDown ? 1 - _span(0, 600, const Cubic(0.45, 0.05, 0.2, 1)) : 0.0;
    return Positioned.fromRect(
      rect: spot.rect,
      child: Transform.rotate(
        angle: spot.degrees * math.pi / 180,
        child: DeskNoteFace(
          role: role,
          content: role == DeskNoteRole.middle ? widget.middle : (role == DeskNoteRole.left ? DeskWriting.left : DeskWriting.right),
          flip: flip,
          contentOpacity: 1 - _span(0, 250),
          stroke: 3 + (layout.logoStroke - 3) * move,
          outline: Color.lerp(deskOutline(context), logoOutline(context), move),
          radius: 12 + (layout.logoStroke * 0.55 - 12) * move,
          shadow: move < 0.6,
        ),
      ),
    );
  }

  Widget _mark(DeskLayout layout) {
    final appear = _span(_markStart, _markStart + 350);
    if (appear == 0) return const SizedBox.shrink();
    return Positioned(
      left: layout.logoOrigin.dx,
      top: layout.logoOrigin.dy,
      child: Opacity(
        opacity: appear,
        child: NotelyMark(size: layout.logoSize, assembled: true, progress: _span(_markStart, _markEnd)),
      ),
    );
  }

  Widget _word(DeskLayout layout, NotelyTheme notely) {
    final t = _span(_wordStart, _wordStart + 500, NotelyMotion.enter);
    final rule = _span(_wordStart + 300, _wordStart + 750, NotelyMotion.enter);
    return Positioned(
      left: 0,
      right: 0,
      top: layout.logoOrigin.dy + layout.logoSize + 16 * layout.scale,
      child: Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: _wordmark(notely, rule)),
      ),
    );
  }

  Widget _wordmark(NotelyTheme notely, double rule) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Notely',
          style: TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic, fontSize: 50, height: 1, color: notely.text),
        ),
        const SizedBox(height: 12),
        Container(
          width: 64 * rule,
          height: 2,
          decoration: BoxDecoration(color: notely.violet, borderRadius: BorderRadius.circular(1)),
        ),
        if (widget.welcome != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.welcome!,
            style: TextStyle(fontFamily: 'Geist', fontSize: 15, color: notely.text2),
          ),
        ],
      ],
    );
  }

  Widget _reducedFrame(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final v = _c.value;
    final opacity = v < 0.15 ? v / 0.15 : (v > 0.8 ? (1 - v) / 0.2 : 1.0);
    return IgnorePointer(
      ignoring: v > 0.8,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Material(
          color: notely.bg,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [const NotelyMark(size: 160), const SizedBox(height: 16), _wordmark(notely, 1)],
            ),
          ),
        ),
      ),
    );
  }
}
