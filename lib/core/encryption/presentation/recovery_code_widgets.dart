import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

/// The recovery code as a key card: a paper note with the logo's clip, the
/// code split into its groups so it's easy to read and copy by hand.
class RecoveryKeyCard extends StatelessWidget {
  const RecoveryKeyCard({super.key, required this.code, this.caption});

  /// Grouped with dashes, as KeyBackupService makes it.
  final String code;
  final String? caption;

  static const _ink = Color(0xFF22357A);
  static const _paper = Color(0xFFFDFBF7);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outline = dark ? const Color(0xFF5E584F) : const Color(0xFF1F1B16);
    final groups = code.split('-');
    return Transform.rotate(
      angle: -1 * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: outline, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 14))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.key_rounded, size: 18, color: _ink),
                  SizedBox(width: 6),
                  Text(
                    'Notely recovery code',
                    style: TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic, fontSize: 18, color: _ink),
                  ),
                ]),
                const SizedBox(height: 12),
                // Selectable as a whole, for long-press copying too.
                SelectionArea(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < groups.length; i++)
                        _Reveal(
                          delay: Duration(milliseconds: 150 + 120 * i),
                          child: Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: const Color(0xFFEFE9DF), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              groups[i],
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 16,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F1B16),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 10),
                  Text(caption!, style: const TextStyle(fontFamily: 'Geist', fontSize: 11, color: Color(0xFF7B7266))),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 24,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8FA6E8),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: outline, width: 3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades a group in after [delay], once.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const run = Duration(milliseconds: 350);
    final total = NotelyMotion.of(context, delay + run);
    if (total == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: NotelyMotion.enter),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// One box per group of the recovery code: typing moves to the next box,
/// Backspace in an empty box goes back, and a pasted code fills them all.
class RecoveryCodeBoxes extends StatefulWidget {
  const RecoveryCodeBoxes({super.key, required this.onChanged, this.onSubmitted, this.error = false, this.enabled = true});

  /// The whole code, groups joined with dashes.
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final bool error;
  final bool enabled;

  /// Six groups of four and a last group of two: 26 characters.
  static const groupLengths = [4, 4, 4, 4, 4, 4, 2];

  @override
  State<RecoveryCodeBoxes> createState() => RecoveryCodeBoxesState();
}

class RecoveryCodeBoxesState extends State<RecoveryCodeBoxes> with SingleTickerProviderStateMixin {
  late final List<TextEditingController> _boxes = [for (final _ in RecoveryCodeBoxes.groupLengths) TextEditingController()];
  late final List<FocusNode> _focus = [for (final _ in RecoveryCodeBoxes.groupLengths) FocusNode()];
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  String get code => _boxes.map((c) => c.text).join('-');

  @override
  void didUpdateWidget(RecoveryCodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error && !NotelyMotion.reduced(context)) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    for (final c in _boxes) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    _shake.dispose();
    super.dispose();
  }

  /// Fills every box from a whole code, whatever separators it has.
  void fill(String text) {
    final raw = text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    var at = 0;
    for (var i = 0; i < _boxes.length; i++) {
      final len = RecoveryCodeBoxes.groupLengths[i];
      final end = math.min(at + len, raw.length);
      _boxes[i].text = at < raw.length ? raw.substring(at, end) : '';
      at = end;
    }
    final firstGap = _boxes.indexWhere((c) => c.text.length < RecoveryCodeBoxes.groupLengths[_boxes.indexOf(c)]);
    (firstGap == -1 ? _focus.last : _focus[firstGap]).requestFocus();
    widget.onChanged(code);
    setState(() {});
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) return;
    NotelyHaptics.select();
    fill(text);
  }

  void _changed(int i, String value) {
    final len = RecoveryCodeBoxes.groupLengths[i];
    final clean = value.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    // A whole code pasted into one box: spread it out.
    if (clean.length > len) return fill([..._boxes.take(i).map((c) => c.text), clean].join());
    if (clean != value) {
      _boxes[i].value = TextEditingValue(text: clean, selection: TextSelection.collapsed(offset: clean.length));
    }
    if (clean.length == len && i < _boxes.length - 1) _focus[i + 1].requestFocus();
    widget.onChanged(code);
    setState(() {});
  }

  KeyEventResult _key(int i, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace && _boxes[i].text.isEmpty && i > 0) {
      _focus[i - 1].requestFocus();
      final prev = _boxes[i - 1];
      prev.selection = TextSelection.collapsed(offset: prev.text.length);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(math.sin(_shake.value * math.pi * 4) * 6 * (1 - _shake.value), 0),
        child: child,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < _boxes.length; i++)
            SizedBox(
              width: 72,
              child: Focus(
                onKeyEvent: (_, event) => _key(i, event),
                child: TextField(
                  controller: _boxes[i],
                  focusNode: _focus[i],
                  enabled: widget.enabled,
                  autofocus: i == 0,
                  textAlign: TextAlign.center,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: i == _boxes.length - 1 ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: i == _boxes.length - 1 ? (_) => widget.onSubmitted?.call() : null,
                  onChanged: (v) => _changed(i, v),
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, letterSpacing: 0.5, color: notely.text),
                  decoration: InputDecoration(
                    hintText: '•' * RecoveryCodeBoxes.groupLengths[i],
                    hintStyle: TextStyle(color: notely.text4, letterSpacing: 2),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: widget.error
                            ? notely.danger
                            : (_boxes[i].text.length == RecoveryCodeBoxes.groupLengths[i] ? notely.success : notely.borderStrong),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: widget.error ? notely.danger : notely.violet, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A padlock whose shackle springs open, with a soft glow, when [open].
class UnlockPadlock extends StatelessWidget {
  const UnlockPadlock({super.key, required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outline = dark ? const Color(0xFF5E584F) : const Color(0xFF1F1B16);
    return SizedBox(
      height: 140,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: open ? 1 : 0),
        duration: NotelyMotion.of(context, const Duration(milliseconds: 600)),
        curve: const Cubic(0.3, 1.5, 0.5, 1),
        builder: (context, t, _) => Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [notely.violet.withValues(alpha: 0.35), notely.violet.withValues(alpha: 0)]),
                ),
              ),
            ),
            CustomPaint(size: const Size(92, 110), painter: _PadlockPainter(open: t, outline: outline)),
          ],
        ),
      ),
    );
  }
}

class _PadlockPainter extends CustomPainter {
  _PadlockPainter({required this.open, required this.outline});
  final double open;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 140;
    canvas.scale(k);
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    // The shackle lifts and swings open around its left foot.
    canvas.save();
    canvas.translate(38, 70 - 14 * open);
    canvas.rotate(-25 * math.pi / 180 * open);
    canvas.translate(-38, -70);
    canvas.drawPath(
      Path()
        ..moveTo(38, 70)
        ..lineTo(38, 44)
        ..arcToPoint(const Offset(102, 44), radius: const Radius.circular(32))
        ..lineTo(102, 70),
      stroke,
    );
    canvas.restore();
    final body = RRect.fromLTRBR(18, 66, 122, 146, const Radius.circular(16));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFDFBF7));
    canvas.drawRRect(body, Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    final ink = Paint()..color = const Color(0xFF2F4AA0);
    canvas.drawCircle(const Offset(70, 100), 9, ink);
    canvas.drawRRect(RRect.fromLTRBR(66, 102, 74, 124, const Radius.circular(3)), ink);
  }

  @override
  bool shouldRepaint(_PadlockPainter old) => old.open != open || old.outline != outline;
}
