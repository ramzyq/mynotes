import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

class ArchivedNotesView extends ConsumerWidget {
  final AuthUser? authUser;
  const ArchivedNotesView({super.key, this.authUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final uid = authUser?.uid ?? ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final own = ref.watch(notesProvider(uid)).valueOrNull ?? const <Note>[];
    final shared = ref.watch(sharedNotesProvider(uid)).valueOrNull ?? const <Note>[];
    final archived = [...own, ...shared].where((n) => n.isArchived).toList();

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
            'Archive',
            style: TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w700, color: notely.text),
          ),
        ),
        body: archived.isEmpty
            ? Center(child: Text('No archived notes', style: TextStyle(color: notely.text3)))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: archived.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final note = archived[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: notely.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: notely.border)),
                    child: Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              await ref.read(notesServiceProvider).setArchived(uid: uid, note: note, archived: false);
                            } catch (_) {}
                          },
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                            const SizedBox(height: 2),
                            Text('Tap to restore', style: TextStyle(fontSize: 12, color: notely.text3)),
                          ]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await showNotelyDialog<bool>(
                            context: context,
                            title: 'Delete forever?',
                            message: 'This cannot be undone.',
                            actions: [
                              NotelyDialogAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
                              NotelyDialogAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.of(context).pop(true)),
                            ],
                          );
                          if (confirmed == true) {
                            try {
                              await ref.read(notesServiceProvider).deleteNote(uid: uid, noteId: note.id);
                            } catch (_) {}
                          }
                        },
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
