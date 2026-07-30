import 'package:mynotes/core/auth/models/auth_user.dart';

abstract class AuthProvider {
  Stream<AuthUser?> get authStateChanges;

  AuthUser? get currentUser;

  Future<AuthUser> logIn({
    required String email,
    required String password,
  });

  Future<AuthUser> createUser({
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  Future<void> logOut();

  Future<void> sendEmailVerification();

  Future<void> reloadCurrentUser();
}
