import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/notes/data/note.dart';

class NotesService {
  final FirebaseFirestore firestore;
  final CryptoService crypto;
  final KeyManager keyManager;

  const NotesService({
    required this.firestore,
    required this.crypto,
    required this.keyManager,
  });

  CollectionReference<Map<String, dynamic>> _notesCollection(String uid) {
    return firestore.collection('users').doc(uid).collection('notes');
  }

  Stream<List<Note>> watchNotes(String uid) {
    return _notesCollection(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final notes = snapshot.docs.map(Note.fromFirestore).toList();

      final decrypted = <Note>[];
      for (final note in notes) {
        if (note.encryptionVersion >= 1 && note.wrappedKey != null) {
          try {
            final noteKey = await keyManager.unwrapNoteKey(note.wrappedKey!);
            decrypted.add(await note.decryptNote(noteKey, crypto));
          } catch (_) {
            decrypted.add(note);
          }
        } else {
          decrypted.add(note);
        }
      }

      decrypted.sort((left, right) {
        if (left.isPinned != right.isPinned) {
          return left.isPinned ? -1 : 1;
        }

        return right.updatedAt.compareTo(left.updatedAt);
      });
      return decrypted;
    });
  }

  Future<Note> createNote({
    required String uid,
    required String title,
    required String content,
    required int colorIndex,
    bool isPinned = false,
    List<String> audioAttachments = const [],
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now();
    final document = _notesCollection(uid).doc();
    final noteId = document.id;

    final wrappedKey = await keyManager.createNoteKey(noteId);
    final noteKey = await keyManager.unwrapNoteKey(wrappedKey);

    final plainNote = Note(
      id: noteId,
      title: title,
      content: content,
      colorIndex: colorIndex,
      isPinned: isPinned,
      audioAttachments: audioAttachments,
      latitude: latitude,
      longitude: longitude,
      createdAt: now,
      updatedAt: now,
    );

    final encryptedNote = await plainNote.encryptNote(noteKey, crypto);
    await document.set(encryptedNote.copyWith(wrappedKey: wrappedKey).toMap());
    return plainNote;
  }

  Future<void> updateNote({
    required String uid,
    required Note note,
  }) async {
    final docRef = _notesCollection(uid).doc(note.id);
    final doc = await docRef.get();
    final existing = Note.fromFirestore(doc);

    if (existing.wrappedKey == null) {
      throw Exception('Note has no wrapped key - cannot update encrypted');
    }

    final noteKey = await keyManager.unwrapNoteKey(existing.wrappedKey!);
    final updatedPlain = note.copyWith(updatedAt: DateTime.now());
    final encrypted = await updatedPlain.encryptNote(noteKey, crypto);
    await docRef.update(encrypted.copyWith(wrappedKey: existing.wrappedKey).toMap());
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
