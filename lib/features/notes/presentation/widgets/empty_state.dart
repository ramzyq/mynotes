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
    final title = hasQuery ? 'No notes match "$query"' : 'A blank page awaits.';
    final subtitle = hasQuery
        ? 'Try a different search, or clear filters to see everything.'
        : 'Capture a thought, a lecture, a link — Notely syncs it across your devices.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StackedCardsIllustration(notely: notely),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 24, letterSpacing: -0.5, color: notely.text)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: notely.text3, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _StackedCardsIllustration extends StatelessWidget {
  final NotelyTheme notely;
  const _StackedCardsIllustration({required this.notely});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 96,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: 8 + i * 8,
              top: 6 + i * 6,
              child: Transform.rotate(
                angle: (-6 + i * 5) * 3.14159 / 180,
                child: Container(
                  width: 80,
                  height: 68,
                  decoration: BoxDecoration(
                    color: i == 2 ? notely.surface : notely.surface2,
                    border: Border.all(color: notely.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
