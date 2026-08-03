import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/presentation/note_editor_view.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

class _MockNotesService extends Mock implements NotesService {}

AuthUser _user() => const AuthUser(
    uid: 'u1', email: 'maya@example.com', displayName: 'Maya', isEmailVerified: true);

Widget _wrap(_MockNotesService notesService) => ProviderScope(
      overrides: [
        notesServiceProvider.overrideWithValue(notesService),
        notesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
      ],
      child: MaterialApp(
        theme: buildNotelyTheme(Brightness.light),
        home: NoteEditorView(authUser: _user()),
      ),
    );

void main() {
  final notesService = _MockNotesService();

  testWidgets('adding a tag and closing the sheet does not use a disposed controller', (tester) async {
    await tester.pumpWidget(_wrap(notesService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit tags'));
    await tester.pumpAndSettle();

    final tagField = find.descendant(
      of: find.byType(GlassModalSheet),
      matching: find.byType(TextField),
    );
    expect(tagField, findsOneWidget);

    await tester.enterText(tagField, 'Work');
    await tester.pump();
    final addButton = find.descendant(
      of: find.byType(GlassModalSheet),
      matching: find.byIcon(Icons.add_circle_outline),
    );
    await tester.tap(addButton);
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
