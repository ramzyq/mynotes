import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/features/notes/data/note.dart';

class NotesService {
  final FirebaseFirestore firestore;

  const NotesService({required this.firestore});

  factory NotesService.instance() {
    return NotesService(firestore: FirebaseFirestore.instance);
  }

  CollectionReference<Map<String, dynamic>> _notesCollection(String uid) {
    return firestore.collection('users').doc(uid).collection('notes');
  }

  Stream<List<Note>> watchNotes(String uid) {
    return _notesCollection(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final notes = snapshot.docs.map(Note.fromFirestore).toList();
      notes.sort((left, right) {
        if (left.isPinned != right.isPinned) {
          return left.isPinned ? -1 : 1;
        }

        return right.updatedAt.compareTo(left.updatedAt);
      });
      return notes;
    });
  }

  Future<Note> createNote({
    required String uid,
    required String title,
    required String content,
    required int colorIndex,
    bool isPinned = false,
  }) async {
    final now = DateTime.now();
    final document = _notesCollection(uid).doc();
    final note = Note(
      id: document.id,
      title: title,
      content: content,
      colorIndex: colorIndex,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );

    await document.set(note.toMap());
    return note;
  }

  Future<void> updateNote({
    required String uid,
    required Note note,
  }) async {
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await _notesCollection(uid).doc(note.id).update(updatedNote.toMap());
  }

  Future<void> deleteNote({
    required String uid,
    required String noteId,
  }) async {
    await _notesCollection(uid).doc(noteId).delete();
  }

  Future<void> togglePin({
    required String uid,
    required Note note,
  }) async {
    await _notesCollection(uid).doc(note.id).update({
      'isPinned': !note.isPinned,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
