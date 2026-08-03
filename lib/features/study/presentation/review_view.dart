import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';
import 'package:mynotes/features/study/services/spaced_repetition.dart';

class ReviewView extends ConsumerStatefulWidget {
  final AuthUser authUser;

  const ReviewView({super.key, required this.authUser});

  @override
  ConsumerState<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<ReviewView> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<Note> _cards = [];

  Future<void> _rateCard(int quality) async {
    final note = _cards[_currentIndex];
    final result = calculateSM2(
      quality: quality,
      easeFactor: note.studyEaseFactor ?? 2.5,
      repetitions: note.studyRepetitions ?? 0,
      interval: note.studyInterval ?? 0,
    );

    await ref.read(notesServiceProvider).updateStudyProgress(
      uid: widget.authUser.uid,
      noteId: note.id,
      studyInterval: result.interval,
      studyEaseFactor: result.easeFactor,
      studyRepetitions: result.repetitions,
      studyDueAt: result.dueAt,
    );

    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      setState(() {
        _currentIndex = 0;
        _showAnswer = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueCards = ref.watch(dueCardsProvider(widget.authUser.uid));
    final notely = NotelyTheme.of(context);

    return GlassPage(
      background: const NotelyBackground(),
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: GlassAppBar(
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          title: Text(
            'Study',
            style: TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w700, color: notely.text),
          ),
        ),
        body: dueCards.when(
        data: (cards) {
          _cards = cards;
          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: notely.text4),
                  const SizedBox(height: 24),
                  const Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No cards due for review.',
                    style: TextStyle(color: notely.text3),
                  ),
                ],
              ),
            );
          }

          final note = cards[_currentIndex];
          final parts = (note.content ?? '').split('\n');
          final question = parts.isNotEmpty ? parts.first : note.displayTitle;
          final answer = parts.length > 1 ? parts.sublist(1).join('\n') : '';

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${_currentIndex + 1} of ${cards.length} cards',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: notely.text3,
                      ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / cards.length,
                  backgroundColor: notely.surface2,
                  valueColor: AlwaysStoppedAnimation<Color>(notely.violet),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAnswer = !_showAnswer),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: notely.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: notely.border),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: notely.violet,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              question,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (_showAnswer && answer.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Divider(color: notely.border),
                              const SizedBox(height: 12),
                              Text(
                                'Answer',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: notely.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                answer,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: notely.text2,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                            if (!_showAnswer)
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Text(
                                    'Tap to reveal answer',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: notely.text4,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showAnswer) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _RatingButton(
                        label: 'Again',
                        quality: 1,
                        color: Colors.redAccent,
                        onTap: () => _rateCard(1),
                      ),
                      const SizedBox(width: 8),
                      _RatingButton(
                        label: 'Hard',
                        quality: 2,
                        color: Colors.orangeAccent,
                        onTap: () => _rateCard(2),
                      ),
                      const SizedBox(width: 8),
                      _RatingButton(
                        label: 'Good',
                        quality: 3,
                        color: const Color(0xFF8AA7FF),
                        onTap: () => _rateCard(3),
                      ),
                      const SizedBox(width: 8),
                      _RatingButton(
                        label: 'Easy',
                        quality: 4,
                        color: const Color(0xFF86E7C8),
                        onTap: () => _rateCard(4),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final int quality;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({
    required this.label,
    required this.quality,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
