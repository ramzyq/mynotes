import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

class ShareService {
  final FirebaseFirestore firestore;
  final NotesService notesService;
  final KeyManager keyManager;
  final CryptoService crypto;

  ShareService({
    required this.firestore,
    required this.notesService,
    required this.keyManager,
    required this.crypto,
  });

  Future<void> ensureUserProfile({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    await firestore.collection('users').doc(uid).set({
      'email': email.toLowerCase(),
      'displayName': displayName ?? '',
    }, SetOptions(merge: true));
  }

  Future<String?> lookupUserByEmail(String email) async {
    final snapshot = await firestore
        .collection('users')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
  }

  Future<void> shareNote({
    required String uid,
    required Note note,
    required String collaboratorEmail,
    required String collaboratorName,
  }) async {
    final collaboratorUid = await lookupUserByEmail(collaboratorEmail);
    if (collaboratorUid == null) {
      throw Exception('User with email $collaboratorEmail not found');
    }

    if (collaboratorUid == uid) {
      throw Exception('Cannot share a note with yourself');
    }

    final noteRef =
        firestore.collection('users').doc(uid).collection('notes').doc(note.id);

    final existingNote = await noteRef.get();
    final data = existingNote.data() ?? {};

    final currentCollaborators =
        List<String>.from(data['collaborators'] ?? []);
    if (currentCollaborators.contains(collaboratorUid)) {
      throw Exception('Already shared with this user');
    }

    final currentEncryptedKeys =
        Map<String, String>.from(data['encryptedKeys'] ?? {});

    final storedEncryptionVersion =
        (data['encryptionVersion'] as int?) ?? note.encryptionVersion;
    final storedWrappedKey = data['wrappedKey'] ?? note.wrappedKey;

    if (storedEncryptionVersion >= 1 && storedWrappedKey != null) {
      final noteKey = await keyManager
          .unwrapNoteKey((storedWrappedKey as Map).cast<String, String>());
      final encryptedKey = await keyManager.wrapNoteKeyForCollaborator(
        noteKey: noteKey,
        collaboratorUid: collaboratorUid,
      );
      currentEncryptedKeys[collaboratorUid] = encryptedKey;
    }

    currentCollaborators.add(collaboratorUid);

    await noteRef.update({
      'collaborators': currentCollaborators,
      'encryptedKeys': currentEncryptedKeys,
      'sharedBy': uid,
      'sharedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> removeCollaborator({
    required String uid,
    required Note note,
    required String collaboratorUid,
  }) async {
    final noteRef =
        firestore.collection('users').doc(uid).collection('notes').doc(note.id);

    final existingNote = await noteRef.get();
    final data = existingNote.data() ?? {};

    final collaborators =
        List<String>.from(data['collaborators'] ?? []);
    collaborators.remove(collaboratorUid);

    final encryptedKeys =
        Map<String, String>.from(data['encryptedKeys'] ?? {});
    encryptedKeys.remove(collaboratorUid);

    final updateData = <String, dynamic>{
      'collaborators': collaborators,
      'encryptedKeys': encryptedKeys,
    };

    if (collaborators.isEmpty) {
      updateData['sharedBy'] = null;
      updateData['sharedAt'] = null;
    }

    await noteRef.update(updateData);
  }

  String getShareableLink(Note note) {
    return 'Note sharing link (coming soon)';
  }
}
