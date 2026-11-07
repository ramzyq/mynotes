import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/features/auth/presentation/login_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

/// Records what the app hands to the sign-in server.
class _RecordingAuth implements AuthProvider {
  String? sentPassword;

  @override
  Future<AuthUser> logIn({required String email, required String password}) async {
    sentPassword = password;
    return AuthUser(uid: 'u1', email: email, displayName: 'Maya', isEmailVerified: true);
  }

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
  Future<void> logOut() async {}
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<String> verifyPasswordResetCode(String code) => throw UnimplementedError();
  @override
  Future<void> confirmPasswordReset({required String code, required String newPassword}) =>
      throw UnimplementedError();
  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<void> replacePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> reauthenticate({String? password}) async {}
  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> applyActionCode(String code) async {}
}

void main() {
  testWidgets('sign-in sends the derived auth secret, never the password', (tester) async {
    final auth = _RecordingAuth();
    final deriver = PasswordSecretDeriver(iterations: 1000);
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(AuthService(auth)),
      passwordSecretDeriverProvider.overrideWithValue(deriver),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: const LoginView()),
    ));
    await tester.enterText(find.byType(TextField).at(0), 'Maya@Example.com');
    await tester.enterText(find.byType(TextField).at(1), 'correct horse battery');
    await tester.tap(find.text('Sign in').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();

    final expected = await tester.runAsync(
        () => deriver.derive(email: 'maya@example.com', password: 'correct horse battery'));
    expect(auth.sentPassword, isNotNull);
    expect(auth.sentPassword, isNot(contains('correct horse battery')));
    expect(auth.sentPassword, expected!.authSecret);
    expect(container.read(pendingPasswordKeyProvider), expected.backupKey,
        reason: 'only the backup key is kept, for the key setup gate');
  });
}
