import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

final notesServiceProvider = Provider<NotesService>((ref) {
  return NotesService(
    firestore: FirebaseFirestore.instance,
    crypto: ref.watch(cryptoServiceProvider),
    keyManager: ref.watch(keyManagerProvider),
  );
});

final notesProvider = StreamProvider.family<List<Note>, String>((ref, uid) {
  final notesService = ref.watch(notesServiceProvider);
  return notesService.watchNotes(uid);
});
