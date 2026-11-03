import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart' show UserNotLoggedInAuthException, WeakPasswordAuthException, UserAlreadyExistsAuthException, InvalidCredentialAuthException, GenericAuthException, UserNotFoundAuthException, WrongPasswordAuthException, TooManyRequestsAuthException, UserDisabledAuthException, GoogleSignInCancelledException;
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException, GoogleAuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mynotes/core/error/error_handler.dart';

class FirebaseAuthProvider implements AuthProvider {
  @override
  Stream<AuthUser?> get authStateChanges {
    return FirebaseAuth.instance.authStateChanges().map((user) {
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
      } else if (e.code == 'wrong-password') {
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
    } else {
      throw UserNotLoggedInAuthException();
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
