import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/features/auth/presentation/login_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

class _FakeAuth implements AuthProvider {
  int appleSignIns = 0;
  Object? appleError;

  @override
  Future<AuthUser> signInWithApple() async {
    appleSignIns++;
    if (appleError != null) throw appleError!;
    return const AuthUser(uid: 'u1', email: 'x@privaterelay.appleid.com', isEmailVerified: true, usesApple: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _FakeAuth auth;
  setUp(() => auth = _FakeAuth());
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> open(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(AuthService(auth))],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: const LoginView()),
    ));
  }

  testWidgets('iPhone: Continue with Apple is offered, above Google', (tester) async {
    await open(tester, TargetPlatform.iOS);
    final apple = find.text('Continue with Apple');
    final google = find.text('Continue with Google');
    expect(apple, findsOneWidget);
    expect(tester.getTopLeft(apple).dy, lessThan(tester.getTopLeft(google).dy));

    await tester.ensureVisible(apple);
    await tester.tap(apple);
    await tester.pumpAndSettle();
    expect(auth.appleSignIns, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android: no Apple button (the provider is set up for iOS)', (tester) async {
    await open(tester, TargetPlatform.android);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('cancelling Apple sign-in says nothing', (tester) async {
    auth.appleError = AppleSignInCancelledException();
    await open(tester, TargetPlatform.iOS);
    await tester.ensureVisible(find.text('Continue with Apple'));
    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('an email already used with another sign-in method is explained', (tester) async {
    auth.appleError = UserAlreadyExistsAuthException();
    await open(tester, TargetPlatform.iOS);
    await tester.ensureVisible(find.text('Continue with Apple'));
    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already has a Notely account'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
