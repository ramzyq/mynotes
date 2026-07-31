import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

final dueCardsProvider =
    StreamProvider.family<List<Note>, String>((ref, uid) {
  final notesService = ref.watch(notesServiceProvider);
  return notesService.watchStudyCards(uid);
});

final dueCountProvider = StreamProvider.family<int, String>((ref, uid) {
  final notesService = ref.watch(notesServiceProvider);
  return notesService.watchStudyCards(uid).map((cards) => cards.length);
});
