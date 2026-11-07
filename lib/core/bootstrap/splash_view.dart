import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/widgets/notely_mark.dart';

/// The animated launch screen. The native splash shows only the paper
/// colour, so this picks up seamlessly: the notes assemble, the writing
/// appears, then the name rises in. [onFinished] fires once the animation
/// has played (immediately under reduce motion).
class SplashView extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashView({super.key, required this.onFinished});

  static const Duration duration = Duration(milliseconds: 1550);

  static const Color paper = Color(0xFFF7F4EE);
  static const Color night = Color(0xFF161513);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: SplashView.duration);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (NotelyMotion.reduced(context)) {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
    } else {
      _controller.forward().whenComplete(() {
        if (mounted) widget.onFinished();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _span(double start, double end) =>
      NotelyMotion.enter.transform(((_controller.value - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? const Color(0xFFEFE9DE) : const Color(0xFF1F1B16);
    final accent = dark ? const Color(0xFF8FA6E8) : const Color(0xFF2F4AA0);
    final muted = dark ? const Color(0xFF9A9184) : const Color(0xFF7B7266);
    return Scaffold(
      backgroundColor: dark ? SplashView.night : SplashView.paper,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final word = _span(0.6, 0.85);
          final rule = _span(0.72, 0.92);
          final foot = _span(0.78, 1);
          return Stack(
            children: [
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NotelyMark(size: 150, progress: (_controller.value / 0.65).clamp(0.0, 1.0)),
                      const SizedBox(height: 22),
                      Opacity(
                        opacity: word,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - word)),
                          child: Text(
                            'Notely',
                            style: TextStyle(
                              fontFamily: 'Instrument Serif',
                              fontStyle: FontStyle.italic,
                              fontSize: 48,
                              height: 1,
                              color: text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        widthFactor: 1,
                        child: SizedBox(
                          width: 64,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 64 * rule,
                              height: 2,
                              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(1)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 56,
                child: SafeArea(
                  top: false,
                  child: Opacity(
                    opacity: foot,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: muted),
                        const SizedBox(width: 6),
                        Text(
                          'Encrypted on your device',
                          style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
