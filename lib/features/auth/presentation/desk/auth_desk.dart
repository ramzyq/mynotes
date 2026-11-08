import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_layout.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_note.dart';

/// What the notes are doing behind the card.
enum DeskPose {
  /// Drifting slowly: nothing is being typed.
  drift,

  /// Leaning toward the card: the email field has focus.
  lean,

  /// Turned over: a password is being typed, or the account is locked.
  faceDown,

  /// Gone: a scene of its own has the stage (the new password note).
  cleared,
}

/// The sign-in screens' shared scene: three notes from the logo on the
/// page, and a frosted glass card holding the form.
class AuthDesk extends StatefulWidget {
  const AuthDesk({
    super.key,
    required this.card,
    this.pose = DeskPose.drift,
    this.middle = DeskWriting.ideas,
    this.middleClip = false,
    this.showMiddle = true,
    this.scene,
    this.cardKey,
    this.shakerKey,
    this.showBack = false,
    this.glow = false,
  });

  final Widget card;
  final DeskPose pose;

  /// What's written on the middle note.
  final Widget middle;

  /// The logo's clip on top of the middle note (the fresh notebook).
  final bool middleClip;

  /// False when a scene takes the middle note's place (the envelope).
  final bool showMiddle;

  /// Drawn over the notes, under the card: the key note, the envelope.
  final Widget? scene;

  /// Lets a screen find the card on screen (the sign-in moment starts there).
  final GlobalKey? cardKey;

  /// Lets a screen shake the card (a wrong password).
  final GlobalKey<CardShakerState>? shakerKey;

  /// A back button, for screens pushed on top of sign-in.
  final bool showBack;

  /// A soft accent glow behind the notes (the reset is done).
  final bool glow;

  @override
  State<AuthDesk> createState() => _AuthDeskState();
}

class _AuthDeskState extends State<AuthDesk> with SingleTickerProviderStateMixin {
  // One slow loop drives every note's drift; each note goes round a whole
  // number of times per loop, so it never jumps.
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NotelyMotion.ambient(context)) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: notely.bg,
      body: LayoutBuilder(
        builder: (context, box) {
          final layout = DeskLayout(box.biggest, top: padding.top + 8);
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: widget.glow ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.5),
                          radius: 0.8,
                          colors: [notely.violet.withValues(alpha: 0.28), notely.violet.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final role in DeskNoteRole.values)
                if (role != DeskNoteRole.middle || widget.showMiddle) _note(layout, role),
              if (widget.scene != null) Positioned.fill(child: widget.scene!),
              Positioned.fill(child: _cardArea(layout)),
              if (widget.showBack && Navigator.of(context).canPop())
                Positioned(
                  top: padding.top + 4,
                  left: 4,
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _note(DeskLayout layout, DeskNoteRole role) {
    final spot = layout.desk(role);
    final s = layout.scale;
    final lean = switch (role) {
      DeskNoteRole.left => Offset(12 * s, 18 * s),
      DeskNoteRole.right => Offset(-14 * s, 18 * s),
      DeskNoteRole.middle => Offset(0, 22 * s),
    };
    final target = switch (widget.pose) {
      DeskPose.lean => lean,
      DeskPose.cleared => Offset(0, -40 * s),
      _ => Offset.zero,
    };
    final drifting = widget.pose == DeskPose.drift;
    final duration = NotelyMotion.of(context, const Duration(milliseconds: 650));
    return Positioned.fromRect(
      rect: spot.rect,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: widget.pose == DeskPose.cleared ? 0 : 1,
          duration: NotelyMotion.of(context, const Duration(milliseconds: 450)),
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(end: target),
            duration: duration,
            curve: NotelyMotion.enter,
            builder: (context, offset, child) => TweenAnimationBuilder<double>(
              tween: Tween(end: drifting ? 1 : 0),
              duration: duration,
              builder: (context, weight, child) => AnimatedBuilder(
                animation: _drift,
                builder: (context, child) {
                  final (dx, dy, turn) = _driftAt(role, _drift.value, s);
                  return Transform.translate(
                    offset: offset + Offset(dx, dy) * weight,
                    child: Transform.rotate(angle: (spot.degrees + turn * weight) * math.pi / 180, child: child),
                  );
                },
                child: child,
              ),
              child: child,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DeskNote(
                    role: role,
                    faceDown: widget.pose == DeskPose.faceDown,
                    delay: Duration(milliseconds: 120 * role.index),
                    content: switch (role) {
                      DeskNoteRole.left => DeskWriting.left,
                      DeskNoteRole.right => DeskWriting.right,
                      DeskNoteRole.middle => widget.middle,
                    },
                  ),
                ),
                if (role == DeskNoteRole.middle && widget.middleClip)
                  Positioned(
                    top: -14 * s,
                    left: spot.rect.width / 2 - 10 * s,
                    child: AnimatedOpacity(
                      opacity: widget.pose == DeskPose.faceDown ? 0 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: 20 * s,
                        height: 26 * s,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8FA6E8),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: deskOutline(context), width: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Each note's drift at loop position [t]: a gentle figure of a few pixels
  /// and a few degrees.
  static (double, double, double) _driftAt(DeskNoteRole role, double t, double s) {
    final (cycles, phase, ax, ay, turn) = switch (role) {
      DeskNoteRole.left => (3, 0.0, 6.0, 10.0, 3.0),
      DeskNoteRole.right => (2, 0.3, -6.0, 12.0, -3.0),
      DeskNoteRole.middle => (3, 0.6, 3.0, -8.0, 2.0),
    };
    final wave = (1 - math.cos(2 * math.pi * (t * cycles + phase))) / 2;
    return (ax * s * wave, ay * s * wave, turn * wave);
  }

  Widget _cardArea(DeskLayout layout) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          // The card sits at the bottom, leaving the notes room above it
          // where there's space, and scrolls when the keyboard needs it.
          final topRoom = math.min(180.0 * layout.scale, box.maxHeight * 0.3);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(14, topRoom, 14, 14),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - topRoom - 14)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _CardRise(
                      child: CardShaker(key: widget.shakerKey, child: GlassCard(key: widget.cardKey, child: widget.card)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The card rises into place once, when the screen opens.
class _CardRise extends StatelessWidget {
  const _CardRise({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NotelyMotion.of(context, const Duration(milliseconds: 800)),
      curve: NotelyMotion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 70 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Frosted glass: the notes show through, blurred, behind the form.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          decoration: BoxDecoration(
            color: notely.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: notely.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A serif title with its last words in italic accent: "Welcome *back.*"
class DeskTitle extends StatelessWidget {
  const DeskTitle(this.plain, this.accent, {super.key});
  final String plain;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Text.rich(
      TextSpan(
        text: '$plain ',
        children: [
          TextSpan(text: accent, style: TextStyle(fontStyle: FontStyle.italic, color: notely.violet)),
        ],
      ),
      style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 34, height: 1.05, color: notely.text),
    );
  }
}

/// The line under a title.
class DeskSubtitle extends StatelessWidget {
  const DeskSubtitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Text(text, style: TextStyle(fontFamily: 'Geist', fontSize: 13.5, height: 1.45, color: NotelyTheme.of(context).text2)),
    );
  }
}

/// Shakes its child side to side when [shake] is called: a wrong password.
class CardShaker extends StatefulWidget {
  const CardShaker({super.key, required this.child});
  final Widget child;

  @override
  State<CardShaker> createState() => CardShakerState();
}

class CardShakerState extends State<CardShaker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  void shake() {
    if (NotelyMotion.reduced(context)) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final dx = math.sin(t * math.pi * 4) * 7 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
