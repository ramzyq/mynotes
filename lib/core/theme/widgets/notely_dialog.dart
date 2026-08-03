import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class NotelyDialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isPrimary;

  const NotelyDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isPrimary = false,
  });
}

Future<T?> showNotelyDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  required List<NotelyDialogAction> actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final notely = NotelyTheme.of(context);
      return AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: content ?? (message != null ? Text(message) : null),
        actions: [
          for (final action in actions)
            if (action.isPrimary)
              FilledButton(
                onPressed: action.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: notely.violet,
                  foregroundColor: Colors.white,
                ),
                child: Text(action.label),
              )
            else
              TextButton(
                onPressed: action.onPressed,
                style: action.isDestructive
                    ? TextButton.styleFrom(foregroundColor: Colors.redAccent)
                    : null,
                child: Text(action.label),
              ),
        ],
      );
    },
  );
}
