import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/account/presentation/account_sheet.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthUser _user() => const AuthUser(uid: 'u1', email: 'maya@example.com', displayName: 'Maya', isEmailVerified: true);

Note _n(String id, {bool archived = false}) => Note(
      id: id, title: 'T$id', content: 'c', colorIndex: 0, isPinned: false,
      isArchived: archived, createdAt: DateTime(2024, 1, 1), updatedAt: DateTime(2024, 1, 1));

Widget _wrap({AuthUser? user}) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_user())),
        notesProvider.overrideWith((ref, uid) => Stream.value([_n('a'), _n('b', archived: true)])),
        sharedNotesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
        dueCountProvider.overrideWith((ref, uid) => Stream.value(2)),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: AccountSheet(authUser: user ?? _user()))),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows profile, privacy line, and menu rows', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Maya'), findsOneWidget);
    expect(find.textContaining('encrypted on this device'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('2 due'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('change password is offered only to password accounts', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsNothing, reason: 'Google-only account');

    await tester.pumpWidget(_wrap(
      user: const AuthUser(uid: 'u1', email: 'maya@example.com', isEmailVerified: true, hasPassword: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('appearance row toggles theme mode', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
  });
}
