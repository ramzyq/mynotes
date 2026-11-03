import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
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
  // Rated cards leave the due list (their due date moves into the future),
  // so the current card is always the first one. [_reviewed] only drives the
  // progress label.
  int _reviewed = 0;
  bool _showAnswer = false;

  Future<void> _rateCard(Note note, int quality) async {
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

    if (!mounted) return;
    setState(() {
      _reviewed++;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dueCards = ref.watch(dueCardsProvider(widget.authUser.uid));
    final notely = NotelyTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return NotelyPage(
      title: 'Study',
      body: dueCards.when(
        data: (cards) {
          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 32, color: notely.text3),
                    const SizedBox(height: 16),
                    Text(
                      _reviewed > 0 ? 'Done for today' : 'Nothing to review',
                      style: textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        _reviewed > 0
                            ? 'You reviewed $_reviewed ${_reviewed == 1 ? 'card' : 'cards'}. They come back when they are due.'
                            : 'Turn a note into a flashcard from its ⋯ menu. The first line is the question, the rest is the answer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Geist', fontSize: 14, height: 1.45, color: notely.text2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final note = cards.first;
          final parts = (note.content ?? '').split('\n');
          final question = parts.isNotEmpty && parts.first.trim().isNotEmpty ? parts.first : note.displayTitle;
          final answer = parts.length > 1 ? parts.sublist(1).join('\n').trim() : '';
          final total = _reviewed + cards.length;
          final rule = kNotePalette[note.colorIndex % kNotePalette.length];

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Card ${_reviewed + 1} of $total',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          color: notely.text2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        note.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(minHeight: 4, value: (_reviewed + 1) / total),
                  ),
                  const SizedBox(height: 24),
                  // The card: an index card with its heading rule in the
                  // note's color. Tap anywhere on it to turn it over.
                  Expanded(
                    child: Material(
                      color: notely.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: notely.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() => _showAnswer = !_showAnswer),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                              child: Text(question, style: textTheme.displayMedium?.copyWith(fontSize: 28)),
                            ),
                            Container(height: 1.5, color: rule.withValues(alpha: 0.55)),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: _showAnswer
                                    ? Text(
                                        answer.isEmpty ? 'This card has no answer lines yet.' : answer,
                                        style: textTheme.bodyLarge?.copyWith(color: answer.isEmpty ? notely.text3 : notely.text),
                                      )
                                    : Text(
                                        'Tap to show the answer',
                                        style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text3),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: _showAnswer
                        ? Row(
                            children: [
                              _RatingButton(label: 'Again', onTap: () => _rateCard(note, 1)),
                              const SizedBox(width: 8),
                              _RatingButton(label: 'Hard', onTap: () => _rateCard(note, 2)),
                              const SizedBox(width: 8),
                              _RatingButton(label: 'Good', primary: true, onTap: () => _rateCard(note, 3)),
                              const SizedBox(width: 8),
                              _RatingButton(label: 'Easy', onTap: () => _rateCard(note, 4)),
                            ],
                          )
                        : NotelyPrimaryButton(
                            label: 'Show answer',
                            onPressed: () => setState(() => _showAnswer = true),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text("Couldn't load your cards.", style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2)),
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _RatingButton({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: primary
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: EdgeInsets.zero,
                foregroundColor: dark ? notely.bg : Colors.white,
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: EdgeInsets.zero,
                backgroundColor: notely.surface,
              ),
              child: Text(label),
            ),
    );
  }
}
