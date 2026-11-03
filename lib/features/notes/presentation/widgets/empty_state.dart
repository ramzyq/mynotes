import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class EmptyState extends StatelessWidget {
  final String query;
  final String? activeTag;

  const EmptyState({super.key, required this.query, required this.activeTag});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final hasQuery = query.trim().isNotEmpty;
    final title = hasQuery
        ? 'Nothing matches “$query”'
        : activeTag != null
            ? 'No notes tagged $activeTag'
            : 'A blank page';
    final subtitle = hasQuery || activeTag != null
        ? 'Try another word, or clear the filter to see every note.'
        : 'Write a thought, a lecture or a link. It is encrypted on this device before it syncs.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StackedCardsIllustration(notely: notely),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 28, height: 1.15, color: notely.text)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2, height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three index cards, slightly fanned, the top one with its heading rule.
class _StackedCardsIllustration extends StatelessWidget {
  final NotelyTheme notely;
  const _StackedCardsIllustration({required this.notely});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 96,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: 8 + i * 8,
              top: 4 + i * 8,
              child: Transform.rotate(
                angle: (-6 + i * 5) * 3.14159 / 180,
                child: Container(
                  width: 80,
                  height: 64,
                  decoration: BoxDecoration(
                    color: i == 2 ? notely.surface : notely.surface2,
                    border: Border.all(color: notely.borderStrong),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: i == 2
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            Container(height: 1.5, color: notely.violet.withValues(alpha: 0.55)),
                            for (var line = 0; line < 3; line++) ...[
                              const SizedBox(height: 10),
                              Container(height: 1, color: notely.border),
                            ],
                          ],
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
