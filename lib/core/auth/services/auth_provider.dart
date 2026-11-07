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
    required String displayName,
  });

  Future<AuthUser> signInWithGoogle();

  Future<void> logOut();

  Future<void> sendEmailVerification();

  Future<void> reloadCurrentUser();

  // Every `password` / `newPassword` below is the auth secret from
  // PasswordSecretDeriver, never what the user typed.

  /// Email a password reset link to [email].
  Future<void> sendPasswordResetEmail(String email);

  /// The account email a reset code belongs to.
  Future<String> verifyPasswordResetCode(String code);

  Future<void> confirmPasswordReset({required String code, required String newPassword});

  /// Re-authenticate the signed-in user with [currentPassword], then set
  /// [newPassword].
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// Change the password of the account [email] in a separate session,
  /// without signing the app in. Used to replace a password Firebase knows
  /// in plain text before the app ever signs in with it.
  Future<void> replacePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  });
}
