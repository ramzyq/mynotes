import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/account/presentation/archived_notes_view.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

AuthUser _user() => const AuthUser(uid: 'u1', email: 'maya@example.com', displayName: 'Maya', isEmailVerified: true);

Note _n(String id, {bool archived = false}) => Note(
      id: id, title: 'Title $id', content: 'c', colorIndex: 0, isPinned: false,
      isArchived: archived, createdAt: DateTime(2024, 1, 1), updatedAt: DateTime(2024, 1, 1));

Widget _wrap() => ProviderScope(
      overrides: [
        notesProvider.overrideWith((ref, uid) => Stream.value([_n('a', archived: true), _n('b')])),
        sharedNotesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: ArchivedNotesView(authUser: _user())),
    );

void main() {
  testWidgets('lists only archived notes', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Title b'), findsNothing);
  });
}
