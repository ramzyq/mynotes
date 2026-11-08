import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:mynotes/features/auth/presentation/forgot_password_view.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';
import 'package:mynotes/features/auth/services/resend_cooldown.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPasswordService extends Mock implements PasswordAccountService {}

const _user = AuthUser(uid: 'u1', email: 'maya@example.com', isEmailVerified: true, hasPassword: true);

Widget _app(PasswordAccountService service, Widget home) => ProviderScope(
      overrides: [passwordAccountServiceProvider.overrideWithValue(service)],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: home),
    );

Finder _field(String label) => find.widgetWithText(TextField, label);

/// Locked out, step 2: types the reset link in by hand and moves on.
Future<void> _typeLink(WidgetTester tester, String link) async {
  await tester.tap(find.text('Type it instead'));
  await tester.pumpAndSettle();
  await tester.enterText(_field('Reset link from the email'), link);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

/// The page title says "Change password" too; this is the button.
final _changeButton = find.widgetWithText(NotelyPrimaryButton, 'Change password');

void main() {
  late _MockPasswordService service;

  setUpAll(() => registerFallbackValue(_user));
  setUp(() => service = _MockPasswordService());

  testWidgets('forgot password: send link, paste it, set password, back to sign-in', (tester) async {
    when(() => service.sendResetEmail(any())).thenAnswer((_) async {});
    when(() => service.emailForReset(any())).thenAnswer((_) async => 'maya@example.com');
    when(() => service.completeReset(linkOrCode: any(named: 'linkOrCode'), newPassword: any(named: 'newPassword')))
        .thenAnswer((_) async => 'maya@example.com');

    await tester.pumpWidget(_app(service, const LoginView()));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Email'), 'Maya@Example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    verify(() => service.sendResetEmail('Maya@Example.com')).called(1);
    expect(find.textContaining("If a web page asks for a new password, don't use it"), findsOneWidget);
    expect(find.text('Sent to M•••a@Example.com'), findsOneWidget);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'https://x/?mode=resetPassword&oobCode=abc'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Paste the link'));
    await tester.pumpAndSettle();
    verify(() => service.emailForReset('https://x/?mode=resetPassword&oobCode=abc')).called(1);
    expect(find.textContaining('For maya@example.com'), findsOneWidget, reason: 'the checked link names the account');

    await tester.enterText(_field('New password'), 'brand new password');
    await tester.enterText(_field('Confirm new password'), 'brand new password');
    await tester.ensureVisible(find.text('Set new password'));
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    verify(() => service.completeReset(
          linkOrCode: 'https://x/?mode=resetPassword&oobCode=abc',
          newPassword: 'brand new password',
        )).called(1);
    expect(find.text("You're back in."), findsOneWidget);
    await tester.tap(find.widgetWithText(NotelyPrimaryButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets, reason: 'back on the sign-in screen');
    expect(find.text('maya@example.com'), findsOneWidget, reason: 'email filled in');
    expect(find.text('Password changed. Sign in with your new password.'), findsOneWidget);
  });

  testWidgets('forgot password: mismatched passwords are caught before sending', (tester) async {
    when(() => service.sendResetEmail(any())).thenAnswer((_) async {});
    when(() => service.emailForReset(any())).thenAnswer((_) async => 'maya@example.com');
    await tester.pumpWidget(_app(service, const LoginView()));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Email'), 'maya@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    await _typeLink(tester, 'https://x/?mode=resetPassword&oobCode=abc');

    await tester.enterText(_field('New password'), 'brand new password');
    await tester.enterText(_field('Confirm new password'), 'brand new passwrod');
    await tester.ensureVisible(find.text('Set new password'));
    await tester.tap(find.text('Set new password'));
    await tester.pump();

    expect(find.text("The passwords don't match."), findsOneWidget);
    verifyNever(() => service.completeReset(
        linkOrCode: any(named: 'linkOrCode'), newPassword: any(named: 'newPassword')));
  });

  testWidgets('forgot password: an expired link says so as soon as it is entered', (tester) async {
    when(() => service.sendResetEmail(any())).thenAnswer((_) async {});
    when(() => service.emailForReset(any())).thenThrow(InvalidResetCodeAuthException());
    await tester.pumpWidget(_app(service, const LoginView()));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Email'), 'maya@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    await _typeLink(tester, 'old-link');

    expect(find.textContaining("reset link isn't valid any more"), findsOneWidget);
    expect(find.text('Check your inbox.'), findsOneWidget, reason: 'stays on the link step');
    expect(find.text('New password'), findsNothing, reason: 'no new password for a dead link');
    verifyNever(() => service.completeReset(
        linkOrCode: any(named: 'linkOrCode'), newPassword: any(named: 'newPassword')));
  });

  testWidgets("forgot password: the wait to resend survives reopening, per address", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ResendCooldown().start(ResendPurpose.reset, 'maya@example.com');

    await tester.pumpWidget(_app(service, const ForgotPasswordView(initialEmail: 'maya@example.com')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Send again in'), findsOneWidget, reason: 'the earlier send is remembered');

    await tester.enterText(_field('Email'), 'sam@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Send reset link'), findsOneWidget, reason: 'another address has no wait');
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
