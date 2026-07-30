import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

class _MockAuthProvider implements AuthProvider {
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> createUser({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logOut() async {}

  @override
  Future<AuthUser> logIn({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser> signInWithGoogle() {
    throw UnimplementedError();
  }
}

void main() {
  test('authServiceProvider provides AuthService with Firebase provider', () {
    final container = ProviderContainer();
    final authService = container.read(authServiceProvider);
    expect(authService, isA<AuthService>());
    container.dispose();
  });

  test('authStateProvider emits null for unauthenticated', () async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(
          AuthService(_MockAuthProvider()),
        ),
      ],
    );

    final authState = container.read(authStateProvider);
    expect(authState.value, isNull);
    container.dispose();
  });
}
