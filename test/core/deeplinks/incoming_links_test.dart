import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/models/email_action_info.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/deeplinks/incoming_links.dart';
import 'package:mynotes/features/auth/presentation/forgot_password_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';
import 'package:mynotes/features/collaboration/services/join_link_processor.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockJoinLinkProcessor extends Mock implements JoinLinkProcessor {}

class _MockPasswordService extends Mock implements PasswordAccountService {}

/// Records applied codes; signed out unless [user] is set.
class _FakeAuth implements AuthProvider {
  final applied = <String>[];
  int reloads = 0;
  Object? failApply;
  AuthUser? user;
  String? linkEmail = 'maya@example.com';

  @override
  Future<EmailActionInfo> checkActionCode(String code) async => EmailActionInfo(email: linkEmail);

  @override
  Future<void> applyActionCode(String code) async {
    if (failApply != null) throw failApply!;
    applied.add(code);
  }

  @override
  Future<void> reloadCurrentUser() async => reloads++;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(user);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _token = 'AbCdEf0123456789xyzABC';
const _resetLink = 'https://ramzyqnotes.web.app/auth/action?mode=resetPassword&oobCode=xyz';

void main() {
  group('IncomingLink.parse', () {
    IncomingLink? parse(String s) => IncomingLink.parse(Uri.parse(s));

    test('share links on the app domain and the notely scheme', () {
      expect(parse('https://ramzyqnotes.web.app/join/$_token'), isA<JoinIncomingLink>());
      expect(parse('notely://join/$_token'), isA<JoinIncomingLink>());
    });

    test('password reset links on the app domain and the notely scheme', () {
      expect(parse('$_resetLink&apiKey=k'), isA<PasswordResetIncomingLink>());
      expect(parse('notely://auth/action?mode=resetPassword&oobCode=xyz'), isA<PasswordResetIncomingLink>());
    });

    test("Firebase's own email links: every mode gets an answer", () {
      const base = 'https://ramzyqnotes.firebaseapp.com/__/auth/action';
      expect(parse('$base?mode=resetPassword&oobCode=xyz&apiKey=k'), isA<PasswordResetIncomingLink>());
      expect(parse('$base?mode=verifyEmail&oobCode=xyz'),
          isA<VerifyEmailIncomingLink>().having((l) => l.code, 'code', 'xyz'));
      expect(parse('$base?mode=recoverEmail&oobCode=xyz'), isA<RecoverEmailIncomingLink>());
      expect(parse('$base?mode=verifyAndChangeEmail&oobCode=xyz'), isA<ChangeEmailIncomingLink>());
      expect(parse('$base?mode=revertSecondFactorAddition&oobCode=xyz'), isA<UnsupportedEmailActionIncomingLink>());
      expect(parse('$base?mode=resetPassword'), isNull, reason: 'no code');
      expect(parse('https://ramzyqnotes.firebaseapp.com/join/$_token'), isNull, reason: 'only the auth path');
      expect(parse('https://ramzyqnotes.firebaseapp.com/__/auth/handler?mode=verifyEmail&oobCode=x'), isNull);
    });

    test('verification links on the app domain are handled too', () {
      expect(parse('https://ramzyqnotes.web.app/auth/action?mode=verifyEmail&oobCode=xyz'),
          isA<VerifyEmailIncomingLink>());
    });

    test('ignores other domains, other email actions and incomplete links', () {
      expect(parse('https://evil.example/join/$_token'), isNull);
      expect(parse('notely://join/a%2Fb%2Fc%2Fdddddddddddddddd'), isNull);
      expect(parse('https://ramzyqnotes.web.app/auth/action?mode=resetPassword'), isNull);
      expect(parse('notely://join/'), isNull);
      expect(parse('https://ramzyqnotes.web.app/'), isNull);
    });
  });

  group('links arriving while signed out', () {
    late StreamController<Uri> links;
    late _MockJoinLinkProcessor processor;
    late _MockPasswordService passwords;
    late _FakeAuth auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      links = StreamController<Uri>();
      processor = _MockJoinLinkProcessor();
      passwords = _MockPasswordService();
      auth = _FakeAuth();
      registerFallbackValue(Uri());
      when(() => processor.handleUri(any())).thenAnswer((_) async {});
      when(() => passwords.emailForReset(any())).thenAnswer((_) async => 'maya@example.com');
    });
    tearDown(() => links.close());

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(null)),
          authServiceProvider.overrideWithValue(AuthService(auth)),
          incomingLinksProvider.overrideWithValue(links.stream),
          joinLinkProcessorProvider.overrideWithValue(processor),
          passwordAccountServiceProvider.overrideWithValue(passwords),
        ],
        child: const MyApp(),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a reset link opens the reset screen and names the account first', (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse(_resetLink));
      await tester.pumpAndSettle();

      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.textContaining('For maya@example.com'), findsOneWidget);
      expect(find.text('Send reset link'), findsNothing, reason: 'no email step when opened from the link');
      verify(() => passwords.emailForReset(_resetLink)).called(1);
    });

    testWidgets('a link that is no longer valid says so before asking for a password', (tester) async {
      when(() => passwords.emailForReset(any())).thenThrow(InvalidResetCodeAuthException());
      await pumpApp(tester);
      links.add(Uri.parse(_resetLink));
      await tester.pumpAndSettle();

      expect(find.textContaining("reset link isn't valid any more"), findsOneWidget);
      expect(find.text('New password'), findsNothing);
      await tester.tap(find.text('Send a new link'));
      await tester.pumpAndSettle();
      expect(find.text('Send reset link'), findsOneWidget);
    });

    testWidgets('the same reset link twice opens one screen, not two', (tester) async {
      await pumpApp(tester);
      links
        ..add(Uri.parse(_resetLink))
        ..add(Uri.parse(_resetLink));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordView, skipOffstage: false), findsOneWidget);
    });

    testWidgets('a share link is handed to the join processor, which keeps it for sign-in', (tester) async {
      await pumpApp(tester);
      final link = Uri.parse('https://ramzyqnotes.web.app/join/$_token');
      links.add(link);
      await tester.pumpAndSettle();

      verify(() => processor.handleUri(link)).called(1);
    });

    testWidgets("Firebase's verification link is applied in the app", (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse('https://ramzyqnotes.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=abc'));
      await tester.pumpAndSettle();

      expect(auth.applied, ['abc']);
      expect(auth.reloads, 0, reason: 'signed out: nothing to reload');
      expect(find.text('Email verified. Sign in to continue.'), findsOneWidget);
    });

    testWidgets('a verification link for another account says which account', (tester) async {
      auth
        ..user = const AuthUser(uid: 'u1', email: 'maya@example.com', isEmailVerified: false)
        ..linkEmail = 'sam@example.com';
      await pumpApp(tester);
      links.add(Uri.parse('https://ramzyqnotes.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=abc'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Verified sam@example.com'), findsOneWidget);
      expect(auth.reloads, 0, reason: "reloading maya's account would change nothing");
    });

    testWidgets("undoing an email change asks first, then applies", (tester) async {
      auth.linkEmail = 'old@example.com';
      await pumpApp(tester);
      links.add(Uri.parse('https://ramzyqnotes.firebaseapp.com/__/auth/action?mode=recoverEmail&oobCode=r1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('goes back to old@example.com'), findsOneWidget);
      expect(auth.applied, isEmpty, reason: 'nothing happens before confirming');
      await tester.tap(find.text('Undo change'));
      await tester.pumpAndSettle();
      expect(auth.applied, ['r1']);
      expect(find.textContaining('email change was undone'), findsOneWidget);
    });

    testWidgets('a change-email link is never applied', (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse('https://ramzyqnotes.firebaseapp.com/__/auth/action?mode=verifyAndChangeEmail&oobCode=c1'));
      await tester.pumpAndSettle();

      expect(auth.applied, isEmpty);
      expect(find.textContaining("doesn't support changing your account email"), findsOneWidget);
    });

    testWidgets('an expired verification link says what to do', (tester) async {
      auth.failApply = InvalidActionCodeAuthException();
      await pumpApp(tester);
      links.add(Uri.parse('https://ramzyqnotes.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=old'));
      await tester.pumpAndSettle();

      expect(find.textContaining('expired or was already used'), findsOneWidget);
    });

    testWidgets("Firebase's reset link opens the in-app reset screen", (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse('https://ramzyqnotes.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=xyz'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.textContaining('For maya@example.com'), findsOneWidget);
    });

    testWidgets('a link for an action the app has no screen for offers to copy it', (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse(
          'https://ramzyqnotes.firebaseapp.com/__/auth/action?mode=revertSecondFactorAddition&oobCode=x'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Copy it and open it in a browser'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
    });

    testWidgets('unrelated links are ignored', (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse('https://evil.example/join/$_token'));
      await tester.pumpAndSettle();

      verifyNever(() => processor.handleUri(any()));
      expect(find.text('Choose a new password'), findsNothing);
    });
  });
}
