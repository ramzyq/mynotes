import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/core/config/app_config.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/collaboration/models/join_request.dart';
import 'package:mynotes/features/collaboration/models/share_link.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

enum JoinStatus { notFound, ownerLink, alreadyShared, pending, approved, shared }

class JoinResult {
  final JoinStatus status;
  const JoinResult(this.status);
}

/// A sharing problem with a message that is safe to show to the user.
class ShareException implements Exception {
  const ShareException(this.message);
  final String message;
  @override
  String toString() => message;
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

/// Whether the owner's app may finish sharing for a request. Approval-mode
/// links require the owner's own approval; this is enforced by the security
/// rules too, and re-checked here as defense in depth.
bool canCompleteShare({
  required String linkMode,
  required String requestStatus,
  required String? approvedBy,
  required String ownerUid,
}) {
  if (requestStatus != 'approved') return false;
  return linkMode == 'open' || approvedBy == ownerUid;
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

  DocumentReference<Map<String, dynamic>> _noteRef(String ownerUid, String noteId) =>
      firestore.collection('users').doc(ownerUid).collection('notes').doc(noteId);

  /// Publish this user's sharing public key and claim their email lookup.
  Future<void> ensureUserProfile({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    final publicKey = await keyManager.getMyPublicKey();
    final normalized = email.trim().toLowerCase();
    await firestore.collection('users').doc(uid).set({
      'email': normalized,
      'displayName': displayName ?? '',
      'publicKey': base64Encode(publicKey),
    }, SetOptions(merge: true));
    if (normalized.isNotEmpty) {
      await firestore.collection('emailIndex').doc(normalized).set({'uid': uid});
    }
  }

  /// Exact-match lookup; the user directory itself is not listable.
  Future<String?> lookupUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final doc = await firestore.collection('emailIndex').doc(normalized).get();
    return doc.data()?['uid'] as String?;
  }

  /// Share [note] with the user registered under [collaboratorEmail].
  /// Returns the collaborator's uid.
  Future<String> shareNote({
    required String uid,
    required Note note,
    required String collaboratorEmail,
    String collaboratorName = '',
  }) async {
    final collaboratorUid = await lookupUserByEmail(collaboratorEmail);
    if (collaboratorUid == null) {
      throw ShareException('No Notely account uses $collaboratorEmail.');
    }
    if (collaboratorUid == uid) {
      throw const ShareException("You can't share a note with yourself.");
    }

    final existing = Note.fromFirestore(await _noteRef(uid, note.id).get());
    if (existing.collaborators?.contains(collaboratorUid) ?? false) {
      throw const ShareException('This note is already shared with them.');
    }

    final recipientKey = await notesService.publicKeyOf(collaboratorUid);
    if (recipientKey == null) {
      throw const ShareException('They need to open Notely once before you can share with them.');
    }

    await _grantAccess(
      ownerUid: uid,
      noteId: note.id,
      recipientUid: collaboratorUid,
      recipientPublicKey: recipientKey,
    );
    return collaboratorUid;
  }

  /// Add one collaborator. Uses field-level writes so concurrent shares
  /// cannot overwrite each other.
  Future<void> _grantAccess({
    required String ownerUid,
    required String noteId,
    required String recipientUid,
    required List<int> recipientPublicKey,
  }) async {
    final noteKey = await notesService.ownNoteKey(ownerUid, noteId);
    final wrapped = await keyManager.wrapNoteKeyForCollaborator(
      noteKey: noteKey,
      recipientPublicKey: recipientPublicKey,
    );
    await _noteRef(ownerUid, noteId).update({
      NoteFields.collaborators: FieldValue.arrayUnion([recipientUid]),
      '${NoteFields.encryptedKeys}.$recipientUid': wrapped,
      NoteFields.sharedBy: ownerUid,
      NoteFields.sharedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Remove a collaborator and rotate the note key, so the removed user
  /// cannot decrypt anything written after this point.
  Future<void> removeCollaborator({
    required String uid,
    required Note note,
    required String collaboratorUid,
  }) async {
    final current = Note.fromFirestore(await _noteRef(uid, note.id).get());
    final remaining = (current.collaborators ?? const <String>[])
        .where((c) => c != collaboratorUid)
        .toList();
    await notesService.rotateNoteKey(uid: uid, noteId: note.id, collaborators: remaining);
  }

  Future<ShareLink> createShareLink({
    required String uid,
    required Note note,
    required String mode,
  }) async {
    final token = ShareLinkToken.generate();
    // No title or content: the link document is readable by anyone who has
    // the token, and note titles are end-to-end encrypted.
    await firestore.collection('shareLinks').doc(token).set({
      'ownerUid': uid,
      'noteId': note.id,
      'mode': mode,
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
    final linkRef = firestore.collection('shareLinks').doc(token);
    final requests = await linkRef.collection('requests').get();
    final batch = firestore.batch();
    for (final doc in requests.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(linkRef);
    await batch.commit();
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

    if (ownerUid == uid) return const JoinResult(JoinStatus.ownerLink);

    // Reading the note only succeeds if we are already a collaborator.
    var alreadyShared = false;
    try {
      alreadyShared = (await _noteRef(ownerUid, noteId).get()).exists;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    if (alreadyShared) return const JoinResult(JoinStatus.alreadyShared);

    final requestRef = linkRef.collection('requests').doc(uid);
    final requestDoc = await requestRef.get();
    final existing = requestDoc.data();
    final plan = planJoin(
      linkExists: true,
      isOwner: false,
      alreadyShared: false,
      requestExists: requestDoc.exists,
      existingRequestStatus: existing?['status'] as String? ?? 'pending',
      linkMode: mode,
    );

    final publicKeyB64 = base64Encode(recipientPublicKey);
    if (!requestDoc.exists) {
      await requestRef.set({
        'ownerUid': ownerUid,
        'noteId': noteId,
        'recipientUid': uid,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'recipientPublicKey': publicKeyB64,
        'status': plan.requestStatus,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } else if (existing?['recipientPublicKey'] != publicKeyB64) {
      // Recipients may only refresh their own profile fields.
      await requestRef.update({'recipientPublicKey': publicKeyB64});
    }

    return JoinResult(plan.status);
  }

  Stream<List<JoinRequest>> watchOwnerJoinRequests(String ownerUid) {
    return firestore
        .collectionGroup('requests')
        .where('ownerUid', isEqualTo: ownerUid)
        .where('status', whereIn: ['pending', 'approved'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map(JoinRequest.fromDoc).toList());
  }

  Future<void> approveJoinRequest({
    required String ownerUid,
    required String token,
    required String recipientUid,
  }) async {
    await firestore
        .collection('shareLinks')
        .doc(token)
        .collection('requests')
        .doc(recipientUid)
        .update({'status': 'approved', 'approvedBy': ownerUid});
    await completeShareForRequest(
      ownerUid: ownerUid,
      token: token,
      recipientUid: recipientUid,
    );
  }

  Future<void> denyJoinRequest({
    required String token,
    required String recipientUid,
  }) async {
    await firestore
        .collection('shareLinks')
        .doc(token)
        .collection('requests')
        .doc(recipientUid)
        .delete();
  }

  /// Owner side: grant access for an approved request.
  Future<void> completeShareForRequest({
    required String ownerUid,
    required String token,
    required String recipientUid,
  }) async {
    final linkRef = firestore.collection('shareLinks').doc(token);
    final requestRef = linkRef.collection('requests').doc(recipientUid);

    final linkDoc = await linkRef.get();
    final link = linkDoc.data();
    if (link == null || link['ownerUid'] != ownerUid) {
      await requestRef.delete();
      return;
    }

    final request = (await requestRef.get()).data();
    if (request == null) return;
    if (!canCompleteShare(
      linkMode: link['mode'] as String? ?? 'approval',
      requestStatus: request['status'] as String? ?? '',
      approvedBy: request['approvedBy'] as String?,
      ownerUid: ownerUid,
    )) {
      return;
    }
    // The request must point at the link's note, not one the requester chose.
    final noteId = link['noteId'] as String;
    if (request['noteId'] != noteId) return;

    final publicKeyB64 = request['recipientPublicKey'] as String?;
    if (publicKeyB64 == null) return;

    await _grantAccess(
      ownerUid: ownerUid,
      noteId: noteId,
      recipientUid: recipientUid,
      recipientPublicKey: base64Decode(publicKeyB64),
    );
    await requestRef.update({'status': 'shared'});
  }
}
