import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/core/config/app_config.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/collaboration/models/share_link.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

enum JoinStatus { notFound, ownerLink, alreadyShared, pending, approved, shared }

class JoinResult {
  final JoinStatus status;
  final String? noteTitle;
  const JoinResult(this.status, {this.noteTitle});
}

class ShareLinkToken {
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const int length = 22;

  static String generate({math.Random? random}) {
    final rng = random ?? math.Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
  }
}

String buildJoinUrl(String token) => 'https://${appConfig.shareDomain}/join/$token';

({JoinStatus status, String requestStatus}) planJoin({
  required bool linkExists,
  required bool isOwner,
  required bool alreadyShared,
  required bool requestExists,
  required String existingRequestStatus,
  required String linkMode,
}) {
  if (!linkExists) return (status: JoinStatus.notFound, requestStatus: '');
  if (isOwner) return (status: JoinStatus.ownerLink, requestStatus: '');
  if (alreadyShared) {
    return (
      status: JoinStatus.alreadyShared,
      requestStatus: existingRequestStatus,
    );
  }
  if (requestExists) {
    return switch (existingRequestStatus) {
      'shared' => (status: JoinStatus.shared, requestStatus: 'shared'),
      'approved' => (status: JoinStatus.approved, requestStatus: 'approved'),
      _ => (status: JoinStatus.pending, requestStatus: existingRequestStatus),
    };
  }
  if (linkMode == 'open') {
    return (status: JoinStatus.approved, requestStatus: 'approved');
  }
  return (status: JoinStatus.pending, requestStatus: 'pending');
}

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
    final publicKey = await keyManager.getMyPublicKey();
    await firestore.collection('users').doc(uid).set({
      'email': email.toLowerCase(),
      'displayName': displayName ?? '',
      'publicKey': base64Encode(publicKey),
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

    final recipientDoc = await firestore
        .collection('users')
        .doc(collaboratorUid)
        .get();
    final recipientPublicKeyB64 = recipientDoc.data()?['publicKey'] as String?;
    if (recipientPublicKeyB64 == null) {
      throw Exception('Recipient has not set up sharing yet; ask them to open the app once.');
    }

    if (storedEncryptionVersion >= 1 && storedWrappedKey != null) {
      final noteKey = await keyManager
          .unwrapNoteKey((storedWrappedKey as Map).cast<String, String>());
      final encryptedKey = await keyManager.wrapNoteKeyForCollaborator(
        noteKey: noteKey,
        recipientPublicKey: base64Decode(recipientPublicKeyB64),
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

  Future<ShareLink> createShareLink({
    required String uid,
    required Note note,
    required String mode,
  }) async {
    final token = ShareLinkToken.generate();
    await firestore.collection('shareLinks').doc(token).set({
      'ownerUid': uid,
      'noteId': note.id,
      'mode': mode,
      'noteTitlePlain': note.displayTitle,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    return ShareLink(
      token: token,
      url: buildJoinUrl(token),
      mode: mode,
      noteTitle: note.displayTitle,
    );
  }

  Future<void> revokeShareLink({required String token}) async {
    await firestore.collection('shareLinks').doc(token).delete();
  }

  Future<JoinResult> joinSharedNote({
    required String uid,
    required String token,
    required List<int> recipientPublicKey,
    required String recipientName,
    required String recipientEmail,
  }) async {
    final linkRef = firestore.collection('shareLinks').doc(token);
    final linkDoc = await linkRef.get();
    if (!linkDoc.exists) return const JoinResult(JoinStatus.notFound);
    final linkData = linkDoc.data()!;

    final ownerUid = linkData['ownerUid'] as String;
    final noteId = linkData['noteId'] as String;
    final mode = linkData['mode'] as String? ?? 'approval';
    final noteTitle = linkData['noteTitlePlain'] as String? ?? 'Note';

    if (ownerUid == uid) return const JoinResult(JoinStatus.ownerLink);

    final noteRef = firestore
        .collection('users')
        .doc(ownerUid)
        .collection('notes')
        .doc(noteId);
    final requestRef = linkRef.collection('requests').doc(uid);

    bool alreadyShared = false;
    try {
      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) return const JoinResult(JoinStatus.notFound);
      alreadyShared = true;
    } catch (_) {
      alreadyShared = false;
    }
    if (alreadyShared) return const JoinResult(JoinStatus.alreadyShared);

    final requestDoc = await requestRef.get();
    final plan = planJoin(
      linkExists: true,
      isOwner: false,
      alreadyShared: false,
      requestExists: requestDoc.exists,
      existingRequestStatus: requestDoc.exists
          ? (requestDoc.data()?['status'] as String? ?? 'pending')
          : '',
      linkMode: mode,
    );

    if (plan.requestStatus.isNotEmpty &&
        (!requestDoc.exists ||
            requestDoc.data()?['status'] != plan.requestStatus)) {
      await requestRef.set({
        'ownerUid': ownerUid,
        'noteId': noteId,
        'noteTitle': noteTitle,
        'recipientUid': uid,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'recipientPublicKey': base64Encode(recipientPublicKey),
        'status': plan.requestStatus,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    }

    return JoinResult(plan.status, noteTitle: noteTitle);
  }
}
