import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';

/// Three welcome pages shown once, before the first sign-in screen.
/// [onFinish] is called with true for "Get started" (create an account) and
/// false for "I already have an account" or Skip-then-sign-in.
class WelcomeView extends StatefulWidget {
  final void Function(bool createAccount) onFinish;

  const WelcomeView({super.key, required this.onFinish});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  static const _pageCount = 3;
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == _pageCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(page, duration: NotelyMotion.of(context, NotelyMotion.slow), curve: NotelyMotion.enter);
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final pages = [
      _WelcomeCopy(
        lead: 'Notes only ',
        emphasis: 'you',
        tail: ' can read',
        body: 'Every note is locked on your phone before it syncs. Not even we can open it.',
        illustration: (active) => _PrivateIllustration(active: active),
      ),
      _WelcomeCopy(
        lead: 'Catch every ',
        emphasis: 'thought',
        tail: '',
        body:
            'Type it, say it, or snap the whiteboard. Notely turns photos and voice into text right on your phone, even offline.',
        illustration: (active) => _CaptureIllustration(active: active),
      ),
      _WelcomeCopy(
        lead: 'Share safely. ',
        emphasis: 'Remember',
        tail: ' more.',
        body:
            "Invite people by email or link, and only they get the key. Turn notes into flashcards that come back right before you'd forget them.",
        illustration: (active) => _ShareIllustration(active: active),
      ),
    ];

    return Scaffold(
      backgroundColor: notely.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Notely',
                    style: TextStyle(
                      fontFamily: 'Instrument Serif',
                      fontStyle: FontStyle.italic,
                      fontSize: 26,
                      color: notely.text,
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _last ? 0 : 1,
                    duration: NotelyMotion.of(context, NotelyMotion.fast),
                    child: IgnorePointer(
                      ignoring: _last,
                      child: TextButton(
                        onPressed: () => _goTo(_pageCount - 1),
                        style: TextButton.styleFrom(foregroundColor: notely.text2, minimumSize: const Size(64, 44)),
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) =>
                    _WelcomePage(controller: _controller, index: index, active: index == _page, copy: pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: AnimatedSize(
                duration: NotelyMotion.of(context, NotelyMotion.medium),
                curve: NotelyMotion.enter,
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _Dots(count: _pageCount, page: _page),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: NotelyMotion.of(context, NotelyMotion.fast),
                          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                          child: _last
                              ? const SizedBox(key: ValueKey('none'), height: 52)
                              : SizedBox(
                                  key: const ValueKey('next'),
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: () => _goTo(_page + 1),
                                    style: FilledButton.styleFrom(
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(horizontal: 22),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [Text('Next'), SizedBox(width: 6), Icon(Icons.arrow_forward, size: 18)],
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    if (_last) ...[
                      const SizedBox(height: 16),
                      EntranceFade(
                        child: NotelyPrimaryButton(label: 'Get started', onPressed: () => widget.onFinish(true)),
                      ),
                      const SizedBox(height: 4),
                      EntranceFade(
                        delay: const Duration(milliseconds: 80),
                        child: TextButton(
                          onPressed: () => widget.onFinish(false),
                          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                          child: const Text('I already have an account'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCopy {
  final String lead;
  final String emphasis;
  final String tail;
  final String body;
  final Widget Function(bool active) illustration;

  const _WelcomeCopy({
    required this.lead,
    required this.emphasis,
    required this.tail,
    required this.body,
    required this.illustration,
  });
}

class _WelcomePage extends StatelessWidget {
  final PageController controller;
  final int index;
  final bool active;
  final _WelcomeCopy copy;

  const _WelcomePage({required this.controller, required this.index, required this.active, required this.copy});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // How far this page is from the centre: 0 when settled, ±1 a page away.
        final page = controller.hasClients && controller.position.haveDimensions ? controller.page ?? 0 : 0.0;
        final delta = (index - page).clamp(-1.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Transform.translate(
                  // The illustration trails the swipe slightly: a little depth.
                  offset: Offset(delta * width * 0.18, 0),
                  // Shrinks to fit on short phones rather than overflowing.
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: copy.illustration(active)),
                  ),
                ),
              ),
              // The words take what they need, up to a share of the page; on a
              // very short screen (or with large text) they scroll instead of
              // overflowing.
              Flexible(
                flex: 4,
                child: Opacity(
                  opacity: (1 - delta.abs() * 1.4).clamp(0.0, 1.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontFamily: 'Instrument Serif',
                              fontSize: MediaQuery.sizeOf(context).height < 700 ? 32 : 40,
                              height: 1.05,
                              color: notely.text,
                            ),
                            children: [
                              TextSpan(text: copy.lead),
                              TextSpan(
                                text: copy.emphasis,
                                style: TextStyle(fontStyle: FontStyle.italic, color: notely.violet),
                              ),
                              TextSpan(text: copy.tail),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          copy.body,
                          style: TextStyle(fontFamily: 'Geist', fontSize: 15, height: 1.5, color: notely.text2),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int page;

  const _Dots({required this.count, required this.page});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Semantics(
      label: 'Page ${page + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: NotelyMotion.of(context, NotelyMotion.medium),
              curve: NotelyMotion.enter,
              margin: const EdgeInsets.only(right: 6),
              width: i == page ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == page ? notely.violet : notely.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Plays its illustration each time its page becomes the current one.
abstract class _Illustration extends StatefulWidget {
  final bool active;
  const _Illustration({required this.active});

  Widget buildFrame(BuildContext context, double Function(double start, double end, [Curve curve]) at);

  @override
  State<_Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<_Illustration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play(initial: true);
  }

  @override
  void didUpdateWidget(_Illustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _play();
  }

  void _play({bool initial = false}) {
    if (NotelyMotion.reduced(context)) {
      _controller.value = 1;
    } else if (widget.active && (!initial || _controller.value == 0)) {
      _controller.forward(from: 0);
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
      animation: _controller,
      builder: (context, _) => widget.buildFrame(
        context,
        (start, end, [curve = NotelyMotion.enter]) =>
            curve.transform(((_controller.value - start) / (end - start)).clamp(0.0, 1.0)),
      ),
    );
  }
}

Widget _noteCard(BuildContext context, {double width = 150, double height = 186, Widget? child}) {
  final notely = NotelyTheme.of(context);
  return Container(
    width: width,
    // A floor, not a fixed height: large text sizes make the card taller.
    constraints: BoxConstraints(minHeight: height),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: notely.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: notely.border),
      boxShadow: [BoxShadow(color: notely.text.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
    ),
    child:
        child ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in const [0.7, 1.0, 0.85, 0.55])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FractionallySizedBox(
                  widthFactor: w,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(color: notely.surface2, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
          ],
        ),
  );
}

/// Index cards fan out and a lock seal presses on.
class _PrivateIllustration extends _Illustration {
  const _PrivateIllustration({required super.active});

  @override
  Widget buildFrame(BuildContext context, double Function(double, double, [Curve]) at) {
    final notely = NotelyTheme.of(context);
    final fan = at(0, 0.55);
    final seal = at(0.45, 0.9, Curves.elasticOut);
    Widget card(double angle, double dx) => Transform.translate(
      offset: Offset(dx * fan, 0),
      child: Transform.rotate(angle: angle * fan * math.pi / 180, child: _noteCard(context)),
    );
    return SizedBox(
      width: 300,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          card(-12, -58),
          card(12, 58),
          card(0, 0),
          Transform.scale(
            scale: seal,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: notely.violet,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: notely.violet.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

/// A note writes itself, then the ways to capture pop in.
class _CaptureIllustration extends _Illustration {
  const _CaptureIllustration({required super.active});

  @override
  Widget buildFrame(BuildContext context, double Function(double, double, [Curve]) at) {
    final notely = NotelyTheme.of(context);
    const title = 'Lab, week 3';
    final typed = (title.length * at(0.05, 0.4, Curves.linear)).round();
    final lines = at(0.3, 0.62);
    Widget chip(IconData icon, String label, double start) {
      final p = at(start, start + 0.3, Curves.easeOutBack);
      return Transform.scale(
        scale: p,
        child: Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: notely.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: notely.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: notely.violet),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _noteCard(
          context,
          width: 250,
          height: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.substring(0, typed),
                style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 24, color: notely.text),
              ),
              const SizedBox(height: 14),
              for (final w in const [1.0, 0.8, 0.6])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: w * lines,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(color: notely.surface2, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            chip(Icons.document_scanner_outlined, 'Scan text', 0.55),
            chip(Icons.mic_none_rounded, 'Voice', 0.65),
            chip(Icons.place_outlined, 'Place', 0.75),
          ],
        ),
      ],
    );
  }
}

/// Two people meet at a key, then a study card rises.
class _ShareIllustration extends _Illustration {
  const _ShareIllustration({required super.active});

  @override
  Widget buildFrame(BuildContext context, double Function(double, double, [Curve]) at) {
    final notely = NotelyTheme.of(context);
    final meet = at(0, 0.5);
    final key = at(0.3, 0.7, Curves.easeOutBack);
    final card = at(0.55, 1);
    Widget person(String initial, Color color, double dx) => Transform.translate(
      offset: Offset(dx * (1 - meet), 0),
      child: Opacity(
        opacity: meet,
        child: CircleAvatar(
          radius: 30,
          backgroundColor: color,
          child: Text(
            initial,
            style: const TextStyle(fontFamily: 'Geist', fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            person('M', const Color(0xFF3F7D5C), -60),
            const SizedBox(width: 18),
            Transform.scale(
              scale: key,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: notely.violetSoft2, shape: BoxShape.circle),
                child: Icon(Icons.key_rounded, color: notely.violet),
              ),
            ),
            const SizedBox(width: 18),
            person('K', const Color(0xFF6E4A8E), 60),
          ],
        ),
        const SizedBox(height: 26),
        Opacity(
          opacity: card,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - card)),
            child: _noteCard(
              context,
              width: 250,
              height: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Study card · due today',
                    style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: notely.violet),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What do mitochondria do?',
                    style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 20, height: 1.15, color: notely.text),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
