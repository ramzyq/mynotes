import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/notes/data/note.dart';

/// A note in Archive or Trash: margin line, title, a caption, and actions.
class ManagedNoteRow extends StatelessWidget {
  final Note note;
  final String caption;
  final List<Widget> actions;

  const ManagedNoteRow({super.key, required this.note, required this.caption, required this.actions});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: notely.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: notely.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2,
              decoration: BoxDecoration(
                color: kNotePalette[note.colorIndex % kNotePalette.length],
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    note.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w500, color: notely.text),
                  ),
                  const SizedBox(height: 2),
                  Text(caption, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Centered message for an empty Archive or Trash.
class ManagedEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const ManagedEmpty({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: notely.text3),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Geist', fontSize: 14, height: 1.45, color: notely.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
