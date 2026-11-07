import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/auth/models/email_action_info.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';

/// Firebase Auth for one account: stores whatever password it is given and
/// checks it like the real service does.
class _FakeFirebase implements AuthProvider {
  _FakeFirebase({required this.email, required this.password});
  final String email;
  String password;
  bool signedIn = false;

  /// Make the next app sign-in fail as if the connection dropped.
  bool failNextSignIn = false;
  final resetCodes = <String>{};
  final received = <String>[];

  @override
  Future<AuthUser> logIn({required String email, required String password}) async {
    received.add(password);
    appSignIns.add(password);
    if (failNextSignIn) {
      failNextSignIn = false;
      throw GenericAuthException();
    }
    if (email != this.email || password != this.password) throw WrongPasswordAuthException();
    signedIn = true;
    return AuthUser(uid: 'u1', email: email, isEmailVerified: true, hasPassword: true);
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    received.add(currentPassword);
    if (!signedIn) throw UserNotLoggedInAuthException();
    if (currentPassword != password) throw WrongPasswordAuthException();
    received.add(newPassword);
    password = newPassword;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (email == this.email) resetCodes.add('reset-code-0123456789abcdef');
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    if (!resetCodes.contains(code)) throw InvalidResetCodeAuthException();
    return email;
  }

  @override
  Future<void> confirmPasswordReset({required String code, required String newPassword}) async {
    if (!resetCodes.remove(code)) throw InvalidResetCodeAuthException();
    received.add(newPassword);
    password = newPassword;
  }

  /// Password changes made in a separate session; the app is not signed in.
  @override
  Future<void> replacePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (email != this.email || currentPassword != password) throw WrongPasswordAuthException();
    received.add(newPassword);
    password = newPassword;
  }

  /// Every password the app's own session signed in with.
  final appSignIns = <String>[];

  @override
  Future<void> logOut() async => signedIn = false;
  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();
  @override
  AuthUser? get currentUser => null;
  @override
  Future<AuthUser> createUser({required String email, required String password, required String displayName}) =>
      throw UnimplementedError();
  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> reauthenticate({String? password}) async {}
  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> applyActionCode(String code) async {}

  @override
  Future<EmailActionInfo> checkActionCode(String code) async => const EmailActionInfo();
}

class _MemoryStore implements KeyBackupStore {
  final docs = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String uid) async => docs[uid];
  @override
  Future<void> write(String uid, Map<String, dynamic> data) async {
    final existing = docs[uid] ?? <String, dynamic>{};
    final oldSlots = Map<String, dynamic>.from((existing['slots'] as Map?) ?? const {});
    final newSlots = Map<String, dynamic>.from((data['slots'] as Map?) ?? const {});
    docs[uid] = {...existing, ...data, 'slots': {...oldSlots, ...newSlots}};
  }
}

const _email = 'maya@example.com';
const _user = AuthUser(uid: 'u1', email: _email, isEmailVerified: true, hasPassword: true);
final _deriver = PasswordSecretDeriver(iterations: 1000);

/// A device with empty secure storage, sharing [store] with other devices.
KeyBackupService _device(_MemoryStore store) {
  FlutterSecureStorage.setMockInitialValues({});
  return KeyBackupService(keyManager: KeyManager(), store: store);
}

Future<List<int>> _backupKey(String password) async =>
    (await _deriver.derive(email: _email, password: password)).backupKey;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryStore store;
  late _FakeFirebase firebase;
  late KeyBackupService thisDevice;
  late PasswordAccountService service;

  /// An account registered with [password] on this device.
  setUp(() async {
    store = _MemoryStore();
    final secrets = await _deriver.derive(email: _email, password: 'first password');
    firebase = _FakeFirebase(email: _email, password: secrets.authSecret);
    thisDevice = _device(store);
    await thisDevice.prepare(uid: 'u1', passwordKey: secrets.backupKey);
    service = PasswordAccountService(auth: firebase, deriver: _deriver, keyBackup: thisDevice);
  });

  void expectNeverSent(String plain) {
    expect(firebase.received.where((p) => p.contains(plain)), isEmpty,
        reason: '"$plain" must never reach Firebase');
  }

  group('changePassword', () {
    test('switches sign-in and the key backup to the new password', () async {
      firebase.signedIn = true;
      await service.changePassword(user: _user, currentPassword: 'first password', newPassword: 'second password');

      final next = await _deriver.derive(email: _email, password: 'second password');
      expect(firebase.password, next.authSecret);
      expectNeverSent('first password');
      expectNeverSent('second password');

      // A new device now opens the backup with the new password only.
      expect(await _device(store).prepare(uid: 'u1', passwordKey: next.backupKey), isA<KeySetupReady>());
      expect(await _device(store).prepare(uid: 'u1', passwordKey: await _backupKey('first password')),
          isA<KeySetupNeedsRecoveryCode>());
    });

    test('a wrong current password changes nothing', () async {
      firebase.signedIn = true;
      final before = firebase.password;
      await expectLater(
        service.changePassword(user: _user, currentPassword: 'not it', newPassword: 'second password'),
        throwsA(isA<WrongPasswordAuthException>()),
      );
      expect(firebase.password, before);
      expect(await _device(store).prepare(uid: 'u1', passwordKey: await _backupKey('first password')),
          isA<KeySetupReady>());
    });

    test('a short new password is refused before anything is sent', () async {
      await expectLater(
        service.changePassword(user: _user, currentPassword: 'first password', newPassword: 'short'),
        throwsA(isA<PasswordTooShortException>()),
      );
      expect(firebase.received, isEmpty);
    });
  });

  group('reset', () {
    const link = 'https://ramzyqnotes.firebaseapp.com/__/auth/action'
        '?mode=resetPassword&oobCode=reset-code-0123456789abcdef&apiKey=k&lang=en';

    test('sets the new password through the app, never in plain text', () async {
      await service.sendResetEmail(' Maya@Example.com ');
      final email = await service.completeReset(linkOrCode: link, newPassword: 'brand new password');

      expect(email, _email);
      expect(firebase.password, (await _deriver.derive(email: _email, password: 'brand new password')).authSecret);
      expectNeverSent('brand new password');
    });

    test('after a reset this device re-wraps the backup at sign-in', () async {
      await service.sendResetEmail(_email);
      await service.completeReset(linkOrCode: link, newPassword: 'brand new password');

      final newKey = await _backupKey('brand new password');
      expect(await thisDevice.prepare(uid: 'u1', passwordKey: newKey), isA<KeySetupReady>());
      expect(await _device(store).prepare(uid: 'u1', passwordKey: newKey), isA<KeySetupReady>(),
          reason: 'a new device can now use the new password too');
    });

    test('a used or unknown link is refused', () async {
      await service.sendResetEmail(_email);
      await service.completeReset(linkOrCode: link, newPassword: 'brand new password');
      await expectLater(service.completeReset(linkOrCode: link, newPassword: 'another password'),
          throwsA(isA<InvalidResetCodeAuthException>()));
      await expectLater(service.completeReset(linkOrCode: 'not a link', newPassword: 'another password'),
          throwsA(isA<InvalidResetCodeAuthException>()));
    });
  });

  group('repairWebReset', () {
    test('replaces a password set on the web page with a split one', () async {
      firebase.password = 'typed on the web page'; // what the hosted page stores
      List<int>? held;
      await service.repairWebReset(
        email: _email,
        webPassword: 'typed on the web page',
        newPassword: 'chosen in the app',
        holdPasswordKey: (key) => held = key,
      );

      final next = await _deriver.derive(email: _email, password: 'chosen in the app');
      expect(firebase.password, next.authSecret);
      expect(held, next.backupKey);
      expect(firebase.signedIn, isTrue);
      // The app's session (and so key setup) only ever saw the new secret.
      expect(firebase.appSignIns, [next.authSecret]);
      expectNeverSent('chosen in the app');
    });

    test('a failed sign-in after the swap says the new password now works', () async {
      firebase.password = 'typed on the web page';
      firebase.failNextSignIn = true;
      List<int>? held = [1];
      await expectLater(
        service.repairWebReset(
          email: _email,
          webPassword: 'typed on the web page',
          newPassword: 'chosen in the app',
          holdPasswordKey: (key) => held = key,
        ),
        throwsA(isA<PasswordReplacedNotSignedInException>()),
      );
      expect(held, isNull);
      final next = await _deriver.derive(email: _email, password: 'chosen in the app');
      expect(firebase.password, next.authSecret, reason: 'the swap already happened');
    });

    test('a wrong web password leaves nothing behind', () async {
      firebase.password = 'typed on the web page';
      var held = false;
      await expectLater(
        service.repairWebReset(
          email: _email,
          webPassword: 'wrong',
          newPassword: 'chosen in the app',
          holdPasswordKey: (_) => held = true,
        ),
        throwsA(isA<WrongPasswordAuthException>()),
      );
      expect(held, isFalse, reason: 'key setup never got a key');
      expect(firebase.appSignIns, isEmpty);
      expect(firebase.password, 'typed on the web page');
    });
  });

  group('resetCodeFrom', () {
    test('reads the code from the reset link, a wrapped link, or the bare code', () {
      const code = 'reset-code-0123456789abcdef';
      expect(PasswordAccountService.resetCodeFrom(
          'https://x.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=$code'), code);
      final wrapped = Uri.https('x.page.link', '/', {
        'link': 'https://x.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=$code',
      }).toString();
      expect(PasswordAccountService.resetCodeFrom(wrapped), code);
      expect(PasswordAccountService.resetCodeFrom('  $code  '), code);
    });

    test('stops following links nested too deep', () {
      var link = 'https://x.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=reset-code-0123456789abcdef';
      for (var i = 0; i < 6; i++) {
        link = Uri.https('x.page.link', '/', {'link': link}).toString();
      }
      expect(PasswordAccountService.resetCodeFrom(link), isNull);
    });

    test('ignores links for other actions and text without a code', () {
      expect(PasswordAccountService.resetCodeFrom(
          'https://x.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=reset-code-0123456789abcdef'), isNull);
      expect(PasswordAccountService.resetCodeFrom('hello'), isNull);
      expect(PasswordAccountService.resetCodeFrom(''), isNull);
    });
  });
}
