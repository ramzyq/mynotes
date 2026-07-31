import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';
import 'package:mynotes/features/notes/data/comment.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

final notesServiceProvider = Provider<NotesService>((ref) {
  return NotesService(
    firestore: FirebaseFirestore.instance,
    crypto: ref.watch(cryptoServiceProvider),
    keyManager: ref.watch(keyManagerProvider),
  );
});

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService(
    firestore: FirebaseFirestore.instance,
    notesService: ref.watch(notesServiceProvider),
    keyManager: ref.watch(keyManagerProvider),
    crypto: ref.watch(cryptoServiceProvider),
  );
});

final notesProvider = StreamProvider.family<List<Note>, String>((ref, uid) {
  final notesService = ref.watch(notesServiceProvider);
  return notesService.watchNotes(uid);
});

final sharedNotesProvider = StreamProvider.family<List<Note>, String>((ref, uid) {
  final notesService = ref.watch(notesServiceProvider);
  return notesService.getSharedNotes(uid);
});

final commentsProvider =
    StreamProvider.family<List<Comment>, ({String noteOwnerId, String noteId})>(
  (ref, params) {
    final notesService = ref.watch(notesServiceProvider);
    return notesService.watchComments(params.noteOwnerId, params.noteId);
  },
);
