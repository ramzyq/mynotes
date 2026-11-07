import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/deeplinks/incoming_links.dart';
import 'package:mynotes/core/deeplinks/join_link_handler.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/collaboration/services/join_link_processor.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockJoinLinkProcessor extends Mock implements JoinLinkProcessor {}

void main() {
  group('IncomingLink.parse', () {
    IncomingLink? parse(String s) => IncomingLink.parse(Uri.parse(s));

    test('share links on the app domain and the notely scheme', () {
      expect(parse('https://ramzyqnotes.web.app/join/abc123'), isA<JoinIncomingLink>());
      expect(parse('notely://join/abc123'), isA<JoinIncomingLink>());
      expect(JoinLinkHandler.tokenFromUri(Uri.parse('notely://join/abc123')), 'abc123');
    });

    test('password reset links on the app domain and the notely scheme', () {
      expect(parse('https://ramzyqnotes.web.app/auth/action?mode=resetPassword&oobCode=xyz&apiKey=k'),
          isA<PasswordResetIncomingLink>());
      expect(parse('notely://auth/action?mode=resetPassword&oobCode=xyz'), isA<PasswordResetIncomingLink>());
    });

    test('ignores other domains, other email actions and incomplete links', () {
      expect(parse('https://evil.example/join/abc123'), isNull);
      expect(parse('https://ramzyqnotes.web.app/auth/action?mode=verifyEmail&oobCode=xyz'), isNull);
      expect(parse('https://ramzyqnotes.web.app/auth/action?mode=resetPassword'), isNull);
      expect(parse('notely://join/'), isNull);
      expect(parse('https://ramzyqnotes.web.app/'), isNull);
    });
  });

  group('links arriving while signed out', () {
    late StreamController<Uri> links;
    late _MockJoinLinkProcessor processor;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      links = StreamController<Uri>();
      processor = _MockJoinLinkProcessor();
      registerFallbackValue(Uri());
      when(() => processor.handleUri(any())).thenAnswer((_) async {});
    });
    tearDown(() => links.close());

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(null)),
          incomingLinksProvider.overrideWithValue(links.stream),
          joinLinkProcessorProvider.overrideWithValue(processor),
        ],
        child: const MyApp(),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a reset link opens the reset screen with the link filled in', (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse('https://ramzyqnotes.web.app/auth/action?mode=resetPassword&oobCode=xyz'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.text('Send reset link'), findsNothing, reason: 'no email step when opened from the link');
    });

    testWidgets('a share link is handed to the join processor, which keeps it for sign-in', (tester) async {
      await pumpApp(tester);
      final link = Uri.parse('https://ramzyqnotes.web.app/join/abc123');
      links.add(link);
      await tester.pumpAndSettle();

      verify(() => processor.handleUri(link)).called(1);
    });

    testWidgets('unrelated links are ignored', (tester) async {
      await pumpApp(tester);
      links.add(Uri.parse('https://evil.example/join/abc123'));
      await tester.pumpAndSettle();

      verifyNever(() => processor.handleUri(any()));
      expect(find.text('Choose a new password'), findsNothing);
    });
  });
}
