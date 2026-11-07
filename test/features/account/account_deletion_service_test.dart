import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/features/account/services/account_deletion_service.dart';

/// Records the order of auth calls; [failReauth] simulates a wrong password.
class _RecordingAuth implements AuthProvider {
  final calls = <String>[];
  bool failReauth = false;
  bool failDelete = false;

  @override
  Future<void> reauthenticate({String? password}) async {
    calls.add('reauthenticate:${password == null ? 'google' : 'password'}');
    if (failReauth) throw WrongPasswordAuthException();
  }

  @override
  Future<void> deleteCurrentUser() async {
    calls.add('deleteCurrentUser');
    if (failDelete) throw GenericAuthException();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _me = AuthUser(uid: 'me', email: 'Me@Example.com', isEmailVerified: true, hasPassword: true);

Future<void> _seed(FakeFirebaseFirestore db) async {
  Future<void> put(String path, Map<String, dynamic> data) => db.doc(path).set(data);
  // Mine.
  await put('users/me', {'displayName': 'Me', 'publicKey': 'pk'});
  await put('users/me/notes/n1', {'encryptedTitle': 'x'});
  await put('users/me/notes/n1/versions/v1', {'versionNumber': 1});
  await put('users/me/notes/n1/comments/c1', {'authorUid': 'friend'});
  await put('users/me/private/keyBackup', {'slots': {}});
  await put('shareLinks/myLink', {'ownerUid': 'me', 'noteId': 'n1'});
  await put('shareLinks/myLink/requests/friend', {'ownerUid': 'me', 'recipientUid': 'friend'});
  await put('emailIndex/me@example.com', {'uid': 'me'});
  // What I left on a friend's note and link.
  await put('users/friend/notes/f1', {'collaborators': ['me']});
  await put('users/friend/notes/f1/comments/mine', {'authorUid': 'me'});
  await put('users/friend/notes/f1/comments/theirs', {'authorUid': 'friend'});
  await put('shareLinks/friendLink', {'ownerUid': 'friend', 'noteId': 'f1'});
  await put('shareLinks/friendLink/requests/me', {'ownerUid': 'friend', 'recipientUid': 'me'});
  await put('shareLinks/friendLink/requests/other', {'ownerUid': 'friend', 'recipientUid': 'other'});
  // Someone else's.
  await put('users/friend', {'displayName': 'Friend'});
  await put('emailIndex/friend@example.com', {'uid': 'friend'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late _RecordingAuth auth;
  late KeyManager keys;
  late AccountDeletionService service;
  final cleaned = <String>[];
  Future<void> Function() pendingWrites = () async {};

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    await _seed(db);
    auth = _RecordingAuth();
    keys = KeyManager()..setActiveUser('me');
    await keys.generateMasterKey();
    cleaned.clear();
    pendingWrites = () async {};
    service = AccountDeletionService(
      firestore: db,
      auth: auth,
      deriver: PasswordSecretDeriver(iterations: 1000),
      keyManager: keys,
      onDeviceCleanup: (uid) async => cleaned.add(uid),
      waitForPendingWrites: () => pendingWrites(),
      writeTimeout: const Duration(milliseconds: 100),
    );
  });

  Matcher failsAt(AccountDeletionStage stage, Matcher cause) => throwsA(isA<AccountDeletionException>()
      .having((e) => e.stage, 'stage', stage)
      .having((e) => e.cause, 'cause', cause));

  Future<bool> exists(String path) async => (await db.doc(path).get()).exists;

  test('deletes everything the account stored, and nothing of anyone else', () async {
    await service.deleteAccount(user: _me, password: 'my password');

    for (final path in [
      'users/me', 'users/me/notes/n1', 'users/me/notes/n1/versions/v1', 'users/me/notes/n1/comments/c1',
      'users/me/private/keyBackup', 'shareLinks/myLink', 'shareLinks/myLink/requests/friend',
      'emailIndex/me@example.com', 'users/friend/notes/f1/comments/mine', 'shareLinks/friendLink/requests/me',
    ]) {
      expect(await exists(path), isFalse, reason: '$path should be deleted');
    }
    for (final path in [
      'users/friend', 'users/friend/notes/f1', 'users/friend/notes/f1/comments/theirs',
      'shareLinks/friendLink', 'shareLinks/friendLink/requests/other', 'emailIndex/friend@example.com',
    ]) {
      expect(await exists(path), isTrue, reason: '$path belongs to someone else');
    }
  });

  test('re-authenticates first, deletes the Firebase account after the data, then cleans this device', () async {
    await service.deleteAccount(user: _me, password: 'my password');

    expect(auth.calls, ['reauthenticate:password', 'deleteCurrentUser']);
    expect(await keys.hasMasterKey(), isFalse);
    expect(cleaned, ['me']);
  });

  test('a failed re-authentication deletes nothing', () async {
    auth.failReauth = true;
    await expectLater(service.deleteAccount(user: _me, password: 'wrong'),
        failsAt(AccountDeletionStage.verifying, isA<WrongPasswordAuthException>()));

    expect(await exists('users/me/notes/n1'), isTrue);
    expect(await exists('users/me'), isTrue);
    expect(auth.calls, ['reauthenticate:password']);
    expect(await keys.hasMasterKey(), isTrue);
  });

  test('Google accounts re-authenticate with Google', () async {
    const google = AuthUser(uid: 'me', email: 'me@example.com', isEmailVerified: true);
    await service.deleteAccount(user: google);
    expect(auth.calls.first, 'reauthenticate:google');
  });

  test("leaves the email lookup alone if it points at another account", () async {
    await db.doc('emailIndex/me@example.com').set({'uid': 'someoneElse'});
    await service.deleteData(uid: 'me', email: 'me@example.com');
    expect(await exists('emailIndex/me@example.com'), isTrue);
  });

  test("offline, it fails as offline instead of waiting forever, before deleting anything", () async {
    pendingWrites = () => Completer<void>().future; // Queued writes never reach the server.
    await expectLater(
      service.deleteAccount(user: _me, password: 'my password'),
      failsAt(AccountDeletionStage.deletingData,
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
    );
    expect(await exists('users/me/notes/n1'), isTrue);
    expect(auth.calls, ['reauthenticate:password']);
  });

  test('if the Firebase account is not deleted, the data is gone and a retry finishes', () async {
    auth.failDelete = true;
    await expectLater(service.deleteAccount(user: _me, password: 'my password'),
        failsAt(AccountDeletionStage.deletingAccount, isA<GenericAuthException>()));
    expect(await exists('users/me/notes/n1'), isFalse);
    expect(await keys.hasMasterKey(), isTrue, reason: 'the account still exists: keep its key');

    auth.failDelete = false;
    await service.deleteAccount(user: _me, password: 'my password');
    expect(await keys.hasMasterKey(), isFalse);
  });
}
