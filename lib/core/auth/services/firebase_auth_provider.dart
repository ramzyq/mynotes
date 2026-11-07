import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/models/email_action_info.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart' show UserNotLoggedInAuthException, WeakPasswordAuthException, UserAlreadyExistsAuthException, InvalidCredentialAuthException, GenericAuthException, UserNotFoundAuthException, WrongPasswordAuthException, TooManyRequestsAuthException, UserDisabledAuthException, GoogleSignInCancelledException, AppleSignInCancelledException, InvalidResetCodeAuthException, NetworkAuthException, InvalidActionCodeAuthException;
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show AppleAuthProvider, EmailAuthProvider, FirebaseAuth, FirebaseAuthException, GoogleAuthProvider;
import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseApp, FirebaseException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mynotes/core/error/error_handler.dart';

class FirebaseAuthProvider implements AuthProvider {
  @override
  /// userChanges, not authStateChanges: it also fires after reload(), so a
  /// newly verified email moves the app on by itself (authStateChanges only
  /// fires on sign-in and sign-out).
  Stream<AuthUser?> get authStateChanges {
    return FirebaseAuth.instance.userChanges().map((user) {
      if (user == null) {
        return null;
      }

      return AuthUser.fromFirebase(user);
    });
  }

  @override
  Future<AuthUser> createUser({required String email, required String password, required String displayName})
  async {
    try { 
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (displayName.trim().isNotEmpty) {
        await credential.user?.updateProfile(displayName: displayName.trim());
      }
      final user = currentUser;
      if (user != null) {
        return user;
      } else {
        throw UserNotLoggedInAuthException();
      }
    } on FirebaseAuthException catch (e){
      if (e.code == 'weak-password') {
        throw WeakPasswordAuthException();
      } else if (e.code == 'email-already-in-use') {
        throw UserAlreadyExistsAuthException();
      } else if (e.code == 'invalid-email') {
        throw InvalidCredentialAuthException();
      } else {
        throw GenericAuthException();
      }

    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      throw GenericAuthException();
    }

  }

  @override
  AuthUser? get currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return AuthUser.fromFirebase(user);
    } else {
      return null;
    }
  }
  

  @override
  Future<AuthUser> logIn({required String email, required String password}) async{
    try {
       await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = currentUser;
      if (user != null) {
        return Future.value(user);
      } else {
        throw UserNotLoggedInAuthException();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw UserNotFoundAuthException();
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        // invalid-credential is what Firebase reports for a wrong password
        // when email enumeration protection is on.
        throw WrongPasswordAuthException();
      } else if (e.code == 'too-many-requests') {
        throw TooManyRequestsAuthException();
      } else if (e.code == 'user-disabled') {
        throw UserDisabledAuthException();
      } else {
        throw GenericAuthException();
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      throw GenericAuthException();
    }
  }

  @override
  Future<void> logOut() async {
    final user = FirebaseAuth.instance.currentUser;
    _appleAuthorizationCode = null;
    if (user != null) {
      await FirebaseAuth.instance.signOut();
      // Forget the Google account too, so the next sign-in offers the picker.
      if (_googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
    } else {
      throw UserNotLoggedInAuthException();
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    } else {
      throw UserNotLoggedInAuthException();
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      // reload() doesn't refresh the ID token, so its email_verified claim
      // (which the rules check) would stay false until the next hourly
      // refresh. Force it now.
      await user.getIdToken(true);
    } else {
      throw UserNotLoggedInAuthException();
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') throw InvalidCredentialAuthException();
      if (e.code == 'too-many-requests') throw TooManyRequestsAuthException();
      // user-not-found is not reported, so the screen can't be used to
      // find out which emails have accounts.
      if (e.code == 'user-not-found') return;
      throw GenericAuthException();
    }
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await FirebaseAuth.instance.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (e) {
      throw _resetException(e);
    }
  }

  @override
  Future<void> confirmPasswordReset({required String code, required String newPassword}) async {
    try {
      await FirebaseAuth.instance.confirmPasswordReset(code: code, newPassword: newPassword);
    } on FirebaseAuthException catch (e) {
      throw _resetException(e);
    }
  }

  static Exception _resetException(FirebaseAuthException e) => switch (e.code) {
        'expired-action-code' || 'invalid-action-code' || 'user-not-found' || 'user-disabled' =>
          InvalidResetCodeAuthException(),
        'too-many-requests' => TooManyRequestsAuthException(),
        _ => GenericAuthException(),
      };

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw UserNotLoggedInAuthException();
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') throw WrongPasswordAuthException();
      if (e.code == 'too-many-requests') throw TooManyRequestsAuthException();
      throw GenericAuthException();
    }
  }

  @override
  Future<void> replacePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    // A second Firebase app has its own auth session, so the app's
    // authStateChanges never fire and nothing starts key setup.
    const name = 'notely-password-replace';
    FirebaseApp app;
    try {
      app = await Firebase.initializeApp(name: name, options: Firebase.app().options);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
      app = Firebase.app(name);
    }
    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      final credential = await auth.signInWithEmailAndPassword(email: email, password: currentPassword);
      await credential.user!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') throw WrongPasswordAuthException();
      if (e.code == 'user-not-found') throw UserNotFoundAuthException();
      if (e.code == 'too-many-requests') throw TooManyRequestsAuthException();
      throw GenericAuthException();
    } finally {
      await auth.signOut().catchError((Object _) {});
      await app.delete().catchError((Object _) {});
    }
  }

  @override
  Future<void> reauthenticate({String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw UserNotLoggedInAuthException();
    try {
      if (password != null) {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email ?? '', password: password),
        );
        return;
      }
      if (user.providerData.any((p) => p.providerId == 'apple.com')) {
        final credential = await user.reauthenticateWithProvider(_appleProvider());
        // Kept for deleteCurrentUser: Apple requires apps to revoke the
        // user's tokens when the account is deleted.
        _appleAuthorizationCode = credential.additionalUserInfo?.authorizationCode;
        if (_appleAuthorizationCode == null) {
          // Deletion would then go ahead without revoking the Apple tokens,
          // which Apple requires. Make that visible instead of silent.
          AppErrorHandler().handle(
            StateError('Apple re-authentication returned no authorization code; tokens cannot be revoked'),
            StackTrace.current,
          );
        }
        return;
      }
      await _ensureGoogleReady();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw GenericAuthException();
      await user.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw GoogleSignInCancelledException();
      throw GenericAuthException();
    } on FirebaseAuthException catch (e) {
      if (_appleCancelled(e)) throw AppleSignInCancelledException();
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') throw WrongPasswordAuthException();
      if (e.code == 'too-many-requests') throw TooManyRequestsAuthException();
      if (e.code == 'user-mismatch') throw WrongPasswordAuthException();
      if (e.code == 'network-request-failed') throw NetworkAuthException();
      throw GenericAuthException();
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw UserNotLoggedInAuthException();
    try {
      // Apple requires revoking the user's Apple tokens on deletion. A
      // failure here mustn't block the deletion itself. The code is
      // single-use, so it's dropped whatever happens (see finally).
      final appleCode = _appleAuthorizationCode;
      if (appleCode != null) {
        await FirebaseAuth.instance
            .revokeTokenWithAuthorizationCode(appleCode)
            .catchError((Object error, StackTrace stack) => AppErrorHandler().handle(error, stack));
      }
      await user.delete();
      if (_googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') throw NetworkAuthException();
      throw GenericAuthException();
    } finally {
      _appleAuthorizationCode = null;
    }
  }

  @override
  Future<void> applyActionCode(String code) async {
    try {
      await FirebaseAuth.instance.applyActionCode(code);
    } on FirebaseAuthException catch (e) {
      throw _actionCodeException(e);
    }
  }

  @override
  Future<EmailActionInfo> checkActionCode(String code) async {
    try {
      final info = await FirebaseAuth.instance.checkActionCode(code);
      return EmailActionInfo(
        email: info.data['email'] as String?,
        previousEmail: info.data['previousEmail'] as String?,
      );
    } on FirebaseAuthException catch (e) {
      throw _actionCodeException(e);
    }
  }

  static Exception _actionCodeException(FirebaseAuthException e) => switch (e.code) {
        // A retry can't help with any of these: the link itself is unusable.
        'expired-action-code' || 'invalid-action-code' || 'user-disabled' || 'user-not-found' =>
          InvalidActionCodeAuthException(),
        'network-request-failed' => NetworkAuthException(),
        'too-many-requests' => TooManyRequestsAuthException(),
        _ => GenericAuthException(),
      };

  /// From the last Apple re-authentication, for token revocation on delete.
  String? _appleAuthorizationCode;

  static AppleAuthProvider _appleProvider() => AppleAuthProvider()
    ..addScope('email')
    ..addScope('name');

  // Codes FlutterFire uses for a user closing the Apple sheet; the message
  // check covers the native ASAuthorizationError.canceled (1001). Verify on
  // a device when the Apple account is set up.
  static bool _appleCancelled(FirebaseAuthException e) =>
      const {'canceled', 'cancelled', 'user-cancelled', 'web-context-canceled', 'web-context-cancelled',
              'popup-closed-by-user'}.contains(e.code) ||
      (e.message ?? '').contains('AuthorizationError error 1001');

  @override
  Future<AuthUser> signInWithApple() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithProvider(_appleProvider());
      // Apple shares the name only on the very first sign-in.
      final user = credential.user;
      final name = credential.additionalUserInfo?.profile?['name'];
      if (user != null && (user.displayName ?? '').isEmpty && name is Map) {
        final full = [name['firstName'], name['lastName']].whereType<String>().join(' ').trim();
        if (full.isNotEmpty) {
          await user.updateDisplayName(full).catchError((_) {});
          // userChanges (which the app follows) fires on reload, so the
          // name reaches every screen even though sign-in fired first.
          await user.reload().catchError((_) {});
        }
      }
      final current = currentUser;
      if (current == null) throw UserNotLoggedInAuthException();
      return current;
    } on FirebaseAuthException catch (e) {
      if (_appleCancelled(e)) throw AppleSignInCancelledException();
      if (e.code == 'network-request-failed') throw NetworkAuthException();
      if (e.code == 'account-exists-with-different-credential') throw UserAlreadyExistsAuthException();
      throw GenericAuthException();
    }
  }

  static bool _googleReady = false;

  /// google_sign_in 7 must be initialized once before use. On Android the
  /// server client ID comes from google-services.json (default_web_client_id).
  static Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogleReady();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw GenericAuthException();

      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final user = currentUser;
      if (user == null) throw UserNotLoggedInAuthException();
      return user;
    } on GoogleSignInException catch (e, stack) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleSignInCancelledException();
      }
      AppErrorHandler().handle(e, stack);
      throw GenericAuthException();
    } on GenericAuthException {
      rethrow;
    } on UserNotLoggedInAuthException {
      rethrow;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      throw GenericAuthException();
    }
  }

}
