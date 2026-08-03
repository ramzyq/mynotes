import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/notes/data/comment.dart';
import 'package:mynotes/features/notes/data/note.dart';

class NotesService {
  final FirebaseFirestore firestore;
  final CryptoService crypto;
  final KeyManager keyManager;

  NotesService({
    required this.firestore,
    required this.crypto,
    required this.keyManager,
  });

  final _lastVersionTime = <String, DateTime>{};

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

  Stream<List<Note>> watchStudyCards(String uid) {
    return _notesCollection(uid)
        .where('isStudyMaterial', isEqualTo: true)
        .where('studyDueAt', isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .orderBy('studyDueAt', descending: false)
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
      return decrypted;
    });
  }

  Future<List<String>> _resolveLinks(String uid, String content) async {
    final regex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = regex.allMatches(content);
    if (matches.isEmpty) return [];

    final titles = matches.map((m) => m.group(1)!.trim()).toSet().toList();
    final ids = <String>[];
    for (final title in titles) {
      final snapshot = await _notesCollection(uid)
          .where('title', isEqualTo: title)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        ids.add(snapshot.docs.first.id);
      }
    }
    return ids;
  }

  Future<void> saveVersion(String uid, Note note) async {
    final now = DateTime.now();
    final lastTime = _lastVersionTime[note.id];
    if (lastTime != null && now.difference(lastTime).inMinutes < 5) return;

    final versionsRef =
        _notesCollection(uid).doc(note.id).collection('versions');

    final existingVersions =
        await versionsRef.orderBy('createdAt').get();
    if (existingVersions.docs.length >= 50) {
      await existingVersions.docs.first.reference.delete();
    }

    final data = <String, dynamic>{
      'versionNumber': existingVersions.docs.length + 1,
      'createdAt': Timestamp.fromDate(now),
    };

    if (note.encryptionVersion >= 1) {
      data['encryptedContent'] = note.encryptedContent;
      data['encryptedTitle'] = note.encryptedTitle;
    } else {
      data['content'] = note.content;
      data['title'] = note.title;
    }

    await versionsRef.add(data);
    _lastVersionTime[note.id] = now;
  }

  Future<List<Map<String, dynamic>>> getVersions(
      String uid, String noteId) async {
    final snapshot = await _notesCollection(uid)
        .doc(noteId)
        .collection('versions')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    }).toList();
  }

  Future<void> restoreVersion(
      String uid, String noteId, String versionId) async {
    final versionDoc = await _notesCollection(uid)
        .doc(noteId)
        .collection('versions')
        .doc(versionId)
        .get();

    final versionData = versionDoc.data()!;
    final updateData = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (versionData.containsKey('encryptedContent')) {
      updateData['encryptedContent'] = versionData['encryptedContent'];
      updateData['encryptedTitle'] = versionData['encryptedTitle'];
    } else {
      updateData['content'] = versionData['content'];
      updateData['title'] = versionData['title'];
    }

    await _notesCollection(uid).doc(noteId).update(updateData);
  }

  Future<void> deleteNoteVersions(String uid, String noteId) async {
    final versions = await _notesCollection(uid)
        .doc(noteId)
        .collection('versions')
        .get();

    if (versions.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in versions.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<Note> createNote({
    required String uid,
    required String title,
    required String content,
    required int colorIndex,
    bool isPinned = false,
    bool isStudyMaterial = false,
    List<String> audioAttachments = const [],
    double? latitude,
    double? longitude,
    String? placeName,
    List<String> tags = const [],
    DateTime? selfDestructAt,
    bool selfDestructOnRead = false,
  }) async {
    final now = DateTime.now();
    final document = _notesCollection(uid).doc();
    final noteId = document.id;

    final wrappedKey = await keyManager.createNoteKey(noteId);
    final noteKey = await keyManager.unwrapNoteKey(wrappedKey);

    final links = await _resolveLinks(uid, content);

    final plainNote = Note(
      id: noteId,
      title: title,
      content: content,
      colorIndex: colorIndex,
      isPinned: isPinned,
      isStudyMaterial: isStudyMaterial,
      audioAttachments: audioAttachments,
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      tags: tags,
      selfDestructAt: selfDestructAt,
      selfDestructOnRead: selfDestructOnRead,
      createdAt: now,
      updatedAt: now,
      links: links,
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

    await saveVersion(uid, existing);

    final noteKey = await keyManager.unwrapNoteKey(existing.wrappedKey!);
    final links = note.content != null ? await _resolveLinks(uid, note.content!) : existing.links;
    final updatedPlain = note.copyWith(updatedAt: DateTime.now(), links: links);
    final encrypted = await updatedPlain.encryptNote(noteKey, crypto);
    final data = encrypted.copyWith(wrappedKey: existing.wrappedKey).toMap();
    if (note.selfDestructAt == null) {
      data['selfDestructAt'] = FieldValue.delete();
    }
    if (!note.selfDestructOnRead) {
      data['selfDestructOnRead'] = FieldValue.delete();
    }
    await docRef.update(data);
  }

  Future<void> deleteNote({
    required String uid,
    required String noteId,
  }) async {
    await deleteNoteVersions(uid, noteId);
    await _notesCollection(uid).doc(noteId).delete();
  }

  Future<void> updateStudyProgress({
    required String uid,
    required String noteId,
    required int studyInterval,
    required double studyEaseFactor,
    required int studyRepetitions,
    required DateTime studyDueAt,
  }) async {
    await _notesCollection(uid).doc(noteId).update({
      'studyInterval': studyInterval,
      'studyEaseFactor': studyEaseFactor,
      'studyRepetitions': studyRepetitions,
      'studyDueAt': Timestamp.fromDate(studyDueAt),
    });
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

  Future<void> setArchived({
    required String uid,
    required Note note,
    required bool archived,
  }) async {
    await _notesCollection(uid).doc(note.id).update({
      'isArchived': archived,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> archiveMany({
    required String uid,
    required List<Note> notes,
  }) async {
    final batch = firestore.batch();
    for (final note in notes) {
      batch.update(_notesCollection(uid).doc(note.id), {
        'isArchived': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  Future<void> deleteMany({
    required String uid,
    required List<Note> notes,
  }) async {
    for (final note in notes) {
      await deleteNote(uid: uid, noteId: note.id);
    }
  }

  Future<void> setPinnedMany({
    required String uid,
    required List<Note> notes,
    required bool pinned,
  }) async {
    final batch = firestore.batch();
    for (final note in notes) {
      batch.update(_notesCollection(uid).doc(note.id), {
        'isPinned': pinned,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  Future<List<Note>> getBacklinks(String uid, String noteId) async {
    final snapshot = await _notesCollection(uid)
        .where('links', arrayContains: noteId)
        .get();
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
    return decrypted;
  }

  Future<List<String>> searchTitles(String uid, String query) async {
    final snapshot = await _notesCollection(uid)
        .orderBy('title')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();
    return snapshot.docs
        .map((doc) => (doc.data()['title'] as String? ?? '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<String?> resolveTitleToId(String uid, String title) async {
    final snapshot = await _notesCollection(uid)
        .where('title', isEqualTo: title)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
    return null;
  }

  Stream<List<Note>> getSharedNotes(String uid) {
    return firestore
        .collectionGroup('notes')
        .where('collaborators', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final futures = <Future<Note>>[];
      for (final doc in snapshot.docs) {
        final ownerUid = doc.reference.parent.parent!.id;
        final note = Note.fromFirestore(doc);
        futures.add(_decryptSharedNote(uid, note, ownerUid));
      }
      final decrypted = await Future.wait(futures);

      decrypted.sort((left, right) {
        if (left.isPinned != right.isPinned) {
          return left.isPinned ? -1 : 1;
        }
        return right.updatedAt.compareTo(left.updatedAt);
      });
      return decrypted;
    });
  }

  Future<Note> _decryptSharedNote(String uid, Note note, String ownerUid) async {
    if (note.encryptionVersion >= 1 && note.encryptedKeys != null) {
      final encryptedKeyStr = note.encryptedKeys![uid];
      if (encryptedKeyStr != null) {
        try {
          final noteKey = await keyManager.unwrapCollaboratorNoteKey(
            encryptedKeyStr: encryptedKeyStr,
            ownerUid: ownerUid,
          );
          return note.decryptNote(noteKey, crypto);
        } catch (_) {
          return note;
        }
      }
    }
    return note;
  }

  CollectionReference<Map<String, dynamic>> _commentsCollection(
      String noteOwnerId, String noteId) {
    return firestore
        .collection('users')
        .doc(noteOwnerId)
        .collection('notes')
        .doc(noteId)
        .collection('comments');
  }

  Future<void> addComment({
    required String noteOwnerId,
    required String noteId,
    required String authorUid,
    required String authorName,
    required String content,
  }) async {
    final doc = _commentsCollection(noteOwnerId, noteId).doc();
    await doc.set(Comment(
      id: doc.id,
      authorUid: authorUid,
      authorName: authorName,
      content: content,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Stream<List<Comment>> watchComments(String noteOwnerId, String noteId) {
    return _commentsCollection(noteOwnerId, noteId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Comment.fromFirestore).toList());
  }

  Future<void> deleteComment({
    required String noteOwnerId,
    required String noteId,
    required String commentId,
    required String authorUid,
  }) async {
    final doc = _commentsCollection(noteOwnerId, noteId).doc(commentId);
    final snapshot = await doc.get();
    final data = snapshot.data() ?? {};
    if (data['authorUid'] != authorUid) {
      throw Exception('Only the author can delete this comment');
    }
    await doc.delete();
  }
}
