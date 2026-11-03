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
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      final notely = NotelyTheme.of(context);
      return AlertDialog(
        title: Text(title),
        content: content ?? (message != null ? Text(message) : null),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          for (final action in actions)
            if (action.isPrimary)
              FilledButton(
                onPressed: action.onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 40),
                ),
                child: Text(action.label),
              )
            else
              TextButton(
                onPressed: action.onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: action.isDestructive ? notely.danger : notely.text2,
                  minimumSize: const Size(0, 40),
                ),
                child: Text(action.label),
              ),
        ],
      );
    },
  );
}
