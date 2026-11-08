import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/theme/widgets/async_states.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/format/dates.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/account/presentation/managed_note_row.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

class ArchivedNotesView extends ConsumerWidget {
  final AuthUser? authUser;
  const ArchivedNotesView({super.key, this.authUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final uid = authUser?.uid ?? ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final ownAsync = ref.watch(notesProvider(uid));
    final sharedAsync = ref.watch(sharedNotesProvider(uid));
    final own = ownAsync.valueOrNull ?? const <Note>[];
    final shared = sharedAsync.valueOrNull ?? const <Note>[];
    void retry() {
      ref.invalidate(notesProvider(uid));
      ref.invalidate(sharedNotesProvider(uid));
    }

    final archived = [...own, ...shared].where((n) => n.isArchived && !n.isExpired && !n.isTrashed).toList()
      ..sort(noteComparator(NoteSort.updated));
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

    return NotelyPage(
      title: 'Archive',
      body: AsyncStateView<List<Note>>(
        value: ownAsync,
        errorTitle: "Couldn't load the archive",
        onRetry: retry,
        data: (_) => archived.isEmpty
            ? const ManagedEmpty(
                icon: Icons.archive_outlined,
                title: 'Nothing archived',
                message: 'Swipe a note left on the home screen to archive it. It stays searchable here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: archived.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final note = archived[index];
                  return ManagedNoteRow(
                    note: note,
                    caption: 'Edited ${formatDateTime(note.updatedAt)}',
                    actions: [
                      TextButton(
                        onPressed: () => run(
                          () => service().setArchived(uid: uid, note: note, archived: false),
                          "Couldn't restore the note.",
                        ),
                        child: const Text('Restore'),
                      ),
                      IconButton(
                        tooltip: 'Move to trash',
                        icon: Icon(Icons.delete_outline, size: 20, color: notely.text3),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (!await run(
                            () => service().moveToTrash(uid: uid, notes: [note]),
                            "Couldn't move the note to the trash.",
                          )) {
                            return;
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Moved to trash'),
                              // Otherwise the Undo button keeps it up until tapped.
                              persist: false,
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => service().restoreFromTrash(uid: uid, notes: [note]),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
