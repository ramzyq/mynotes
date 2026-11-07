import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/models/email_action_info.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/firebase_auth_provider.dart';

class AuthService implements AuthProvider {
  final AuthProvider provider;

  const AuthService(this.provider);

  factory AuthService.firebase() => AuthService(FirebaseAuthProvider());

  @override
  Stream<AuthUser?> get authStateChanges => provider.authStateChanges;

  @override
  Future<AuthUser> createUser({required String email, required String password, required String displayName}) {
    return provider.createUser(email: email, password: password, displayName: displayName);
  }

  @override
  AuthUser? get currentUser => provider.currentUser;

  @override
  Future<AuthUser> logIn({required String email, required String password}) {
    return provider.logIn(email: email, password: password);
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    return provider.signInWithGoogle();
  }

  @override
  Future<AuthUser> signInWithApple() => provider.signInWithApple();

  @override
  Future<void> logOut() {
    return provider.logOut();
  }

  @override
  Future<void> sendEmailVerification() {
    return provider.sendEmailVerification();
  }

  @override
  Future<void> reloadCurrentUser() {
    return provider.reloadCurrentUser();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => provider.sendPasswordResetEmail(email);

  @override
  Future<String> verifyPasswordResetCode(String code) => provider.verifyPasswordResetCode(code);

  @override
  Future<void> confirmPasswordReset({required String code, required String newPassword}) =>
      provider.confirmPasswordReset(code: code, newPassword: newPassword);

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      provider.changePassword(currentPassword: currentPassword, newPassword: newPassword);

  @override
  Future<void> replacePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) =>
      provider.replacePassword(email: email, currentPassword: currentPassword, newPassword: newPassword);

  @override
  Future<void> reauthenticate({String? password}) => provider.reauthenticate(password: password);

  @override
  Future<void> deleteCurrentUser() => provider.deleteCurrentUser();

  @override
  Future<void> applyActionCode(String code) => provider.applyActionCode(code);

  @override
  Future<EmailActionInfo> checkActionCode(String code) => provider.checkActionCode(code);
}
