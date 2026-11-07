import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/deeplinks/incoming_links.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/presentation/key_setup_gate.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Auth whose user stream behaves like userChanges(): reload()
/// emits the refreshed user.
class _FakeAuth implements AuthProvider {
  final users = StreamController<AuthUser?>.broadcast();
  AuthUser? user;
  bool verifiedOnServer = false;
  int emailsSent = 0;

  void signIn(AuthUser u) {
    user = u;
    users.add(u);
  }

  @override
  Stream<AuthUser?> get authStateChanges => users.stream;
  @override
  AuthUser? get currentUser => user;
  @override
  Future<void> sendEmailVerification() async => emailsSent++;
  @override
  Future<void> reloadCurrentUser() async {
    final u = user!;
    user = AuthUser(uid: u.uid, email: u.email, isEmailVerified: verifiedOnServer, hasPassword: u.hasPassword);
    users.add(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MockKeyBackup extends Mock implements KeyBackupService {}

class _MockNotes extends Mock implements NotesService {}

void main() {
  late _FakeAuth auth;
  late _MockKeyBackup keyBackup;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _FakeAuth();
    keyBackup = _MockKeyBackup();
    // Key setup never finishes here: the test only checks that it starts.
    when(() => keyBackup.prepare(uid: any(named: 'uid'), passwordKey: any(named: 'passwordKey')))
        .thenAnswer((_) => Completer<KeySetupResult>().future);
  });
  tearDown(() => auth.users.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(AuthService(auth)),
        keyBackupServiceProvider.overrideWithValue(keyBackup),
        incomingLinksProvider.overrideWithValue(const Stream.empty()),
        notesServiceProvider.overrideWithValue(_MockNotes()),
      ],
      child: const MyApp(),
    ));
    await tester.pump();
  }

  const unverified = AuthUser(uid: 'u1', email: 'maya@example.com', isEmailVerified: false, hasPassword: true);

  testWidgets('one verify screen, no automatic email, and it moves on once verified', (tester) async {
    await pumpApp(tester);
    auth.signIn(unverified);
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailView, skipOffstage: false), findsOneWidget);
    expect(auth.emailsSent, 0, reason: 'opening the screen must not send an email');

    await tester.tap(find.text('Send the link again'));
    await tester.pumpAndSettle();
    expect(auth.emailsSent, 1);

    // The user opens the link elsewhere; the next check sees it.
    auth.verifiedOnServer = true;
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // Snackbar slides in.

    expect(find.byType(VerifyEmailView, skipOffstage: false), findsNothing);
    expect(find.byType(KeySetupGate), findsOneWidget);
    expect(find.text('Email verified.'), findsOneWidget);
  });

  testWidgets('the background check notices verification on its own', (tester) async {
    await pumpApp(tester);
    auth.signIn(unverified);
    await tester.pumpAndSettle();

    auth.verifiedOnServer = true;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.byType(KeySetupGate), findsOneWidget);
  });
}
