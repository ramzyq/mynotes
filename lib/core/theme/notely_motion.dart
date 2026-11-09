import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// One set of timings and curves for the whole app, so motion feels like
/// one hand made it. Everything collapses to instant when the user has asked
/// the system to reduce motion.
abstract final class NotelyMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);

  /// Decelerating ease for things arriving on screen.
  static const Curve enter = Cubic(0.2, 0.8, 0.2, 1);

  /// Gentle accelerate for things leaving.
  static const Curve exit = Cubic(0.4, 0, 1, 1);

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Endless background motion (the sign-in notes drifting). Off under
  /// `flutter test`, where a loop that never settles would hang every
  /// `pumpAndSettle`. It's global: a test that turns it on must turn it off
  /// again (in `addTearDown`).
  static bool ambientEnabled = !_underTest;
  static final bool _underTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Whether endless background motion should run here.
  static bool ambient(BuildContext context) => ambientEnabled && !reduced(context);

  /// [duration], or zero when reduce motion is on.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;

  /// Fade plus a slight rise: the app's standard way to swap one whole
  /// screen state for another.
  static Widget fadeThrough(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: enter, reverseCurve: exit);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(curved), child: child),
    );
  }
}

/// Page transitions for every pushed route: Android's fade-forwards and the
/// native iOS slide.
const notelyPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);

/// Fades and lifts its child in once, after [delay]. Used to stagger lists
/// and onboarding content. Shows the child immediately under reduce motion.
class EntranceFade extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;

  /// False shows the child at rest from the start: for items that have
  /// already been seen, so a list doesn't replay its entrance on scroll.
  final bool animate;

  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 12,
    this.animate = true,
  });

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade> with SingleTickerProviderStateMixin {
  // The delay is part of one animation (no timers), so nothing is left
  // pending if the widget goes away first.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NotelyMotion.slow + widget.delay,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / (NotelyMotion.slow + widget.delay).inMicroseconds,
      1,
      curve: NotelyMotion.enter,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || NotelyMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, widget.offsetY * (1 - _curve.value)), child: child),
      ),
      child: widget.child,
    );
  }
}
