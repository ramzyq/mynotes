import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';

/// How far account deletion got before it failed, so the user is told the
/// truth: nothing deleted, partly deleted, or only the account left.
enum AccountDeletionStage {
  /// Re-authenticating. Nothing has been deleted.
  verifying,

  /// Deleting data. Some of it may already be gone; running again finishes.
  deletingData,

  /// The data is gone, the Firebase account isn't yet.
  deletingAccount,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.stage, this.cause);
  final AccountDeletionStage stage;
  final Object cause;

  @override
  String toString() => 'Account deletion failed while ${stage.name}: $cause';
}

/// Deletes a Notely account and everything it stored.
///
/// Order matters:
/// 1. Re-authenticate. Firebase only deletes accounts that signed in
///    recently, and failing there must happen before any data is gone.
/// 2. Delete the data in Firestore while still signed in (the rules need
///    the account). First wait for writes still queued from offline edits,
///    so none of them lands after the listing. Every write then waits for
///    the server, up to [writeTimeout]: a write left queued would be refused
///    once the account is gone, leaving data behind. Offline, this fails
///    with `unavailable` instead of waiting forever.
/// 3. Delete the Firebase account.
/// 4. Forget this device's copy of the keys ([onDeviceCleanup]).
///
/// Running it again after a failure picks up whatever is left.
///
/// Not deleted, by design or because the rules don't allow it:
/// - This account's uid in the `collaborators` / `encryptedKeys` of notes
///   other people shared with it: only a note's owner can write the note.
///   The wrapped key is useless without this account's master key, which is
///   deleted, and the owner's share sheet shows "Notely user".
/// - Moderation reports (`reports`), which are immutable for everyone.
/// Under `users/{uid}`, the known subcollections are `notes` and `private`.
/// Clients can't list subcollections, so a new one must be added here.
class AccountDeletionService {
  AccountDeletionService({
    required this.firestore,
    required this.auth,
    required this.deriver,
    required this.keyManager,
    this.onDeviceCleanup,
    Future<void> Function()? waitForPendingWrites,
    this.writeTimeout = const Duration(seconds: 30),
  }) : _waitForPendingWrites = waitForPendingWrites ?? firestore.waitForPendingWrites;

  final FirebaseFirestore firestore;
  final AuthProvider auth;
  final PasswordSecretDeriver deriver;
  final KeyManager keyManager;
  final Duration writeTimeout;
  final Future<void> Function() _waitForPendingWrites;

  /// Device-only state beyond the master key: biometric entries, reminders.
  final Future<void> Function(String uid)? onDeviceCleanup;

  /// [password] is required for password accounts and ignored for Google.
  /// Throws [AccountDeletionException].
  Future<void> deleteAccount({required AuthUser user, String? password}) async {
    await _stage(AccountDeletionStage.verifying, () async {
      final authSecret = user.hasPassword
          ? (await deriver.derive(email: user.email, password: password ?? '')).authSecret
          : null;
      await auth.reauthenticate(password: authSecret);
    });
    await _stage(AccountDeletionStage.deletingData, () => deleteData(uid: user.uid, email: user.email));
    await _stage(AccountDeletionStage.deletingAccount, auth.deleteCurrentUser);

    await keyManager.forgetMasterKey(user.uid);
    await onDeviceCleanup?.call(user.uid);
  }

  static Future<void> _stage(AccountDeletionStage stage, Future<void> Function() run) async {
    try {
      await run();
    } catch (error) {
      throw AccountDeletionException(stage, error);
    }
  }

  /// Wait for the server, or fail as offline rather than hang.
  Future<void> _confirmed(Future<void> write) => write.timeout(
        writeTimeout,
        onTimeout: () => throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

  /// Everything the account stored, including what it left on other
  /// people's notes and share links. Public for tests.
  Future<void> deleteData({required String uid, required String email}) async {
    // Offline edits still queued would otherwise land after the listing.
    await _confirmed(_waitForPendingWrites());

    final userDoc = firestore.collection('users').doc(uid);

    // Own notes, each with its history and comments.
    final notes = await userDoc.collection('notes').get(const GetOptions(source: Source.server));
    for (final note in notes.docs) {
      await _deleteAll(note.reference.collection('versions'));
      await _deleteAll(note.reference.collection('comments'));
      await _confirmed(note.reference.delete());
    }

    // Share links (with their join requests), also for notes already gone.
    final links = await firestore
        .collection('shareLinks')
        .where('ownerUid', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    for (final link in links.docs) {
      // Filtered by owner: the rules refuse an unfiltered list of requests.
      await _deleteAll(link.reference.collection('requests').where('ownerUid', isEqualTo: uid));
      await _confirmed(link.reference.delete());
    }

    // Comments posted on other people's notes (the author name is plain).
    await _deleteAll(firestore.collectionGroup('comments').where('authorUid', isEqualTo: uid));

    // Requests to join other people's notes (they hold name and email).
    await _deleteAll(firestore.collectionGroup('requests').where('recipientUid', isEqualTo: uid));

    // Key backup.
    await _deleteAll(userDoc.collection('private'));

    // Share-by-email lookup, only if it points at this account.
    final normalized = PasswordSecretDeriver.normalizeEmail(email);
    if (normalized.isNotEmpty) {
      final entry = firestore.collection('emailIndex').doc(normalized);
      final index = await entry.get(const GetOptions(source: Source.server));
      if (index.data()?['uid'] == uid) await _confirmed(entry.delete());
    }

    await _confirmed(userDoc.delete());
  }

  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(400).get(const GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await _confirmed(batch.commit());
      if (snapshot.docs.length < 400) return;
    }
  }
}
