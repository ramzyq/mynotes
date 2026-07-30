import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

final notesServiceProvider = Provider<NotesService>((ref) {
  return NotesService.instance();
});

final notesProvider = StreamProvider.family<List<Note>, String>((ref, uid) {
  final notesService = ref.watch(notesServiceProvider);
  return notesService.watchNotes(uid);
});
