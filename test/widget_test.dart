import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mynotes/main.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';

void main() {
  testWidgets('shows the login screen in the dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        authService: AuthService(_FakeAuthProvider()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Note Log'), findsOneWidget);
    expect(find.text('Dark notes workspace for ideas and drafts'), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}

class _FakeAuthProvider implements AuthProvider {
  @override
  Stream<AuthUser?> get authStateChanges => Stream<AuthUser?>.value(null);

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
