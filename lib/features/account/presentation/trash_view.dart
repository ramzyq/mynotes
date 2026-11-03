import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/features/account/presentation/managed_note_row.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

/// Deleted notes, kept for [Note.trashRetention] before they go for good.
class TrashView extends ConsumerWidget {
  final AuthUser? authUser;
  const TrashView({super.key, this.authUser});

  static String daysLeft(Note note, {DateTime? now}) {
    final purgeAt = note.deletedAt!.add(Note.trashRetention);
    final days = purgeAt.difference(now ?? DateTime.now()).inHours / 24;
    if (days <= 1) return 'Deleted for good within a day';
    return 'Deleted for good in ${days.ceil()} days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final uid = authUser?.uid ?? ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final trashed = (ref.watch(notesProvider(uid)).valueOrNull ?? const <Note>[])
        .where((n) => n.isTrashed && !n.isExpired)
        .toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    // Read lazily: building the screen must not create the service.
    NotesService service() => ref.read(notesServiceProvider);

    Future<bool> run(Future<void> Function() action, String failure) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
        return true;
      } catch (error, stack) {
        AppErrorHandler().handle(error, stack);
        messenger.showSnackBar(SnackBar(content: Text(failure)));
        return false;
      }
    }

    Future<bool> confirm(String title, String message) async =>
        await showNotelyDialog<bool>(
          context: context,
          title: title,
          message: message,
          actions: [
            NotelyDialogAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
            NotelyDialogAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.of(context).pop(true)),
          ],
        ) ==
        true;

    return NotelyPage(
      title: 'Trash',
      actions: [
        if (trashed.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: notely.danger),
            onPressed: () async {
              if (!await confirm('Empty the trash?', 'This deletes ${trashed.length} '
                  '${trashed.length == 1 ? 'note' : 'notes'} for good. This cannot be undone.')) {
                return;
              }
              await run(() => service().deleteMany(uid: uid, notes: trashed), "Some notes couldn't be deleted.");
            },
            child: const Text('Empty'),
          ),
        const SizedBox(width: 8),
      ],
      body: trashed.isEmpty
          ? const ManagedEmpty(
              icon: Icons.delete_outline,
              title: 'Trash is empty',
              message: 'Deleted notes stay here for 30 days, so you can bring them back.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: trashed.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = trashed[index];
                return ManagedNoteRow(
                  note: note,
                  caption: daysLeft(note),
                  actions: [
                    TextButton(
                      onPressed: () => run(
                        () => service().restoreFromTrash(uid: uid, notes: [note]),
                        "Couldn't restore the note.",
                      ),
                      child: const Text('Restore'),
                    ),
                    IconButton(
                      tooltip: 'Delete for good',
                      icon: Icon(Icons.delete_forever_outlined, size: 20, color: notely.text3),
                      onPressed: () async {
                        if (!await confirm('Delete for good?', 'This cannot be undone.')) return;
                        await run(() => service().deleteNote(uid: uid, noteId: note.id), "Couldn't delete the note.");
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}
