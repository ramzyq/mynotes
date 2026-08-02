import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/notes/data/note.dart';

final _linkRegex = RegExp(r'\[\[([^\]]+)\]\]');

Widget buildNotePreview(
  BuildContext context,
  Note note,
  List<Note> allNotes,
  void Function(Note) onOpenNote,
) {
  final notely = NotelyTheme.of(context);
  final text = note.previewText;
  final matches = _linkRegex.allMatches(text).toList();
  if (matches.isEmpty) {
    return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.25, height: 1.45, letterSpacing: -0.15, color: notely.text3));
  }

  final existingTitles = allNotes.map((n) => n.title?.trim()).whereType<String>().toSet();
  final spans = <TextSpan>[];
  var lastEnd = 0;
  for (final match in matches) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    final title = match.group(1)!.trim();
    final exists = existingTitles.contains(title);
    spans.add(TextSpan(
      text: title,
      style: TextStyle(
        color: exists ? notely.violetInk : notely.text4,
        decoration: exists ? TextDecoration.underline : TextDecoration.lineThrough,
        decorationColor: exists ? notely.violetInk : notely.text4,
        fontWeight: FontWeight.w500,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          final target = allNotes.where((n) => n.title?.trim() == title).firstOrNull;
          if (target != null) onOpenNote(target);
        },
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }
  return Text.rich(TextSpan(children: spans), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.25, height: 1.45, letterSpacing: -0.15, color: notely.text3));
}

void showArchiveToast(BuildContext context, VoidCallback onUndo) {
  final notely = NotelyTheme.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF1B1427),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    content: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Note archived', style: TextStyle(color: Colors.white, fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        InkWell(onTap: onUndo, child: Text('Undo', style: TextStyle(color: notely.violet, fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    ),
  ));
}
