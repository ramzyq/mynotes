import 'package:mynotes/core/auth/models/auth_user.dart';
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
}
