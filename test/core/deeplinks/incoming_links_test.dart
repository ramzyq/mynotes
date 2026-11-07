import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/deeplinks/incoming_links.dart';
import 'package:mynotes/features/auth/presentation/forgot_password_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';
import 'package:mynotes/features/collaboration/services/join_link_processor.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockJoinLinkProcessor extends Mock implements JoinLinkProcessor {}

class _MockPasswordService extends Mock implements PasswordAccountService {}

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

    test('ignores other domains, other email actions and incomplete links', () {
      expect(parse('https://evil.example/join/$_token'), isNull);
      expect(parse('notely://join/a%2Fb%2Fc%2Fdddddddddddddddd'), isNull);
      expect(parse('https://ramzyqnotes.web.app/auth/action?mode=verifyEmail&oobCode=xyz'), isNull);
      expect(parse('https://ramzyqnotes.web.app/auth/action?mode=resetPassword'), isNull);
      expect(parse('notely://join/'), isNull);
      expect(parse('https://ramzyqnotes.web.app/'), isNull);
    });
  });

  group('links arriving while signed out', () {
    late StreamController<Uri> links;
    late _MockJoinLinkProcessor processor;
    late _MockPasswordService passwords;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      links = StreamController<Uri>();
      processor = _MockJoinLinkProcessor();
      passwords = _MockPasswordService();
      registerFallbackValue(Uri());
      when(() => processor.handleUri(any())).thenAnswer((_) async {});
      when(() => passwords.emailForReset(any())).thenAnswer((_) async => 'maya@example.com');
    });
    tearDown(() => links.close());

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(null)),
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

    testWidgets('unrelated links are ignored', (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse('https://evil.example/join/$_token'));
      await tester.pumpAndSettle();

      verifyNever(() => processor.handleUri(any()));
      expect(find.text('Choose a new password'), findsNothing);
    });
  });
}
