import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';

/// Deletes a Notely account and everything it stored.
///
/// Order matters:
/// 1. Re-authenticate. Firebase only deletes accounts that signed in
///    recently, and failing there must happen before any data is gone.
/// 2. Delete the data in Firestore while still signed in (the rules need
///    the account). Every write is awaited until the server confirms it:
///    a write queued offline would be refused once the account is gone,
///    leaving data behind. So this needs a connection, and says so.
/// 3. Delete the Firebase account.
/// 4. Forget this device's copy of the keys ([onDeviceCleanup]).
class AccountDeletionService {
  AccountDeletionService({
    required this.firestore,
    required this.auth,
    required this.deriver,
    required this.keyManager,
    this.onDeviceCleanup,
  });

  final FirebaseFirestore firestore;
  final AuthProvider auth;
  final PasswordSecretDeriver deriver;
  final KeyManager keyManager;

  /// Device-only state beyond the master key: biometric entries, reminders.
  final Future<void> Function(String uid)? onDeviceCleanup;

  /// [password] is required for password accounts and ignored for Google.
  Future<void> deleteAccount({required AuthUser user, String? password}) async {
    final authSecret = user.hasPassword
        ? (await deriver.derive(email: user.email, password: password ?? '')).authSecret
        : null;
    await auth.reauthenticate(password: authSecret);

    await deleteData(uid: user.uid, email: user.email);
    await auth.deleteCurrentUser();

    await keyManager.forgetMasterKey(user.uid);
    await onDeviceCleanup?.call(user.uid);
  }

  /// Everything the account stored, including what it left on other
  /// people's notes and share links. Public for tests.
  Future<void> deleteData({required String uid, required String email}) async {
    final userDoc = firestore.collection('users').doc(uid);

    // Own notes, each with its history and comments.
    final notes = await userDoc.collection('notes').get(const GetOptions(source: Source.server));
    for (final note in notes.docs) {
      await _deleteAll(note.reference.collection('versions'));
      await _deleteAll(note.reference.collection('comments'));
      await note.reference.delete();
    }

    // Share links (with their join requests), also for notes already gone.
    final links = await firestore
        .collection('shareLinks')
        .where('ownerUid', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    for (final link in links.docs) {
      await _deleteAll(link.reference.collection('requests'));
      await link.reference.delete();
    }

    // Comments posted on other people's notes (the author name is plain).
    await _deleteAll(firestore.collectionGroup('comments').where('authorUid', isEqualTo: uid));

    // Requests to join other people's notes (they hold name and email).
    await _deleteAll(firestore.collectionGroup('requests').where('recipientUid', isEqualTo: uid));

    // Key backup and any other private documents.
    await _deleteAll(userDoc.collection('private'));

    // Share-by-email lookup, only if it points at this account.
    final normalized = PasswordSecretDeriver.normalizeEmail(email);
    if (normalized.isNotEmpty) {
      final entry = firestore.collection('emailIndex').doc(normalized);
      final index = await entry.get(const GetOptions(source: Source.server));
      if (index.data()?['uid'] == uid) await entry.delete();
    }

    await userDoc.delete();
  }

  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(400).get(const GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < 400) return;
    }
  }
}
