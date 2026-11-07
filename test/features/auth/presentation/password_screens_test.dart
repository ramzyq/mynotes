import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/account/presentation/change_password_view.dart';
import 'package:mynotes/features/auth/presentation/login_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';

class _MockPasswordService extends Mock implements PasswordAccountService {}

const _user = AuthUser(uid: 'u1', email: 'maya@example.com', isEmailVerified: true, hasPassword: true);

Widget _app(PasswordAccountService service, Widget home) => ProviderScope(
      overrides: [passwordAccountServiceProvider.overrideWithValue(service)],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: home),
    );

Finder _field(String label) => find.widgetWithText(TextField, label);

/// The page title says "Change password" too; this is the button.
final _changeButton = find.widgetWithText(NotelyPrimaryButton, 'Change password');

void main() {
  late _MockPasswordService service;

  setUpAll(() => registerFallbackValue(_user));
  setUp(() => service = _MockPasswordService());

  testWidgets('forgot password: send link, paste it, set password, back to sign-in', (tester) async {
    when(() => service.sendResetEmail(any())).thenAnswer((_) async {});
    when(() => service.completeReset(linkOrCode: any(named: 'linkOrCode'), newPassword: any(named: 'newPassword')))
        .thenAnswer((_) async => 'maya@example.com');

    await tester.pumpWidget(_app(service, const LoginView()));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Email'), 'Maya@Example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    verify(() => service.sendResetEmail('Maya@Example.com')).called(1);
    expect(find.textContaining("If a web page asks you for a new password, don't enter it there"), findsOneWidget);

    await tester.enterText(_field('Reset link from the email'), 'https://x/?mode=resetPassword&oobCode=abc');
    await tester.enterText(_field('New password'), 'brand new password');
    await tester.enterText(_field('Confirm new password'), 'brand new password');
    await tester.ensureVisible(find.text('Set new password'));
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    verify(() => service.completeReset(
          linkOrCode: 'https://x/?mode=resetPassword&oobCode=abc',
          newPassword: 'brand new password',
        )).called(1);
    expect(find.text('Sign in'), findsWidgets, reason: 'back on the sign-in screen');
    expect(find.text('maya@example.com'), findsOneWidget, reason: 'email filled in');
    expect(find.text('Password changed. Sign in with your new password.'), findsOneWidget);
  });

  testWidgets('forgot password: mismatched passwords are caught before sending', (tester) async {
    when(() => service.sendResetEmail(any())).thenAnswer((_) async {});
    await tester.pumpWidget(_app(service, const LoginView()));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Email'), 'maya@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('New password'), 'brand new password');
    await tester.enterText(_field('Confirm new password'), 'brand new passwrod');
    await tester.ensureVisible(find.text('Set new password'));
    await tester.tap(find.text('Set new password'));
    await tester.pump();

    expect(find.text("The passwords don't match."), findsOneWidget);
    verifyNever(() => service.completeReset(
        linkOrCode: any(named: 'linkOrCode'), newPassword: any(named: 'newPassword')));
  });

  testWidgets('forgot password: an expired link says so', (tester) async {
    when(() => service.sendResetEmail(any())).thenAnswer((_) async {});
    when(() => service.completeReset(linkOrCode: any(named: 'linkOrCode'), newPassword: any(named: 'newPassword')))
        .thenThrow(InvalidResetCodeAuthException());
    await tester.pumpWidget(_app(service, const LoginView()));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Email'), 'maya@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Reset link from the email'), 'old-link');
    await tester.enterText(_field('New password'), 'brand new password');
    await tester.enterText(_field('Confirm new password'), 'brand new password');
    await tester.ensureVisible(find.text('Set new password'));
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(find.textContaining("reset link isn't valid any more"), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget, reason: 'stays on the reset screen');
  });

  testWidgets('change password: success closes the screen', (tester) async {
    when(() => service.changePassword(
          user: any(named: 'user'),
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async {});
    // Opened from a page with a Scaffold, like the notes list in the app.
    await tester.pumpWidget(_app(service, Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChangePasswordView(authUser: _user)),
          ),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Current password'), 'first password');
    await tester.enterText(_field('New password'), 'second password');
    await tester.enterText(_field('Confirm new password'), 'second password');
    await tester.tap(_changeButton);
    await tester.pumpAndSettle();

    verify(() => service.changePassword(
          user: _user, currentPassword: 'first password', newPassword: 'second password',
        )).called(1);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Password changed.'), findsOneWidget);
  });

  testWidgets('change password: a wrong current password keeps the screen open', (tester) async {
    when(() => service.changePassword(
          user: any(named: 'user'),
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(WrongPasswordAuthException());
    await tester.pumpWidget(_app(service, const ChangePasswordView(authUser: _user)));

    await tester.enterText(_field('Current password'), 'not it');
    await tester.enterText(_field('New password'), 'second password');
    await tester.enterText(_field('Confirm new password'), 'second password');
    await tester.tap(_changeButton);
    await tester.pumpAndSettle();

    expect(find.text("That password isn't right."), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
  });
}
