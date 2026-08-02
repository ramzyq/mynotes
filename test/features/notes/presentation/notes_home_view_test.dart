import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/presentation/notes_home_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_card.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';

class _MockNotesService extends Mock implements NotesService {}

AuthUser _user() => const AuthUser(uid: 'u1', email: 'maya@example.com', displayName: 'Maya', isEmailVerified: true);

Note _n(String id, String title, {bool pinned = false, List<String>? tags}) => Note(
      id: id,
      title: title,
      content: 'content $id',
      colorIndex: 0,
      isPinned: pinned,
      tags: tags,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
    );

Widget _wrap(_MockNotesService notesService) => ProviderScope(
      overrides: [
        notesServiceProvider.overrideWithValue(notesService),
        notesProvider.overrideWith((ref, uid) => Stream.value([_n('a', 'Alpha', pinned: true), _n('b', 'Beta', tags: const ['Dev'])])),
        sharedNotesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
        dueCountProvider.overrideWith((ref, uid) => Stream.value(0)),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: NotesHomeView(authUser: _user())),
    );

void main() {
  final notesService = _MockNotesService();
  setUpAll(() {
    registerFallbackValue(_n('f', 'Fallback'));
  });
  setUp(() {
    when(() => notesService.setArchived(uid: any(named: 'uid'), note: any(named: 'note'), archived: any(named: 'archived')))
        .thenAnswer((_) async {});
  });

  testWidgets('renders personalized header and note cards', (tester) async {
    await tester.pumpWidget(_wrap(notesService));
    await tester.pumpAndSettle();
    expect(find.textContaining('Maya'), findsWidgets);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await tester.pumpWidget(_wrap(notesService));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(NoteCard, 'Alpha'), findsNothing);
    expect(find.widgetWithText(NoteCard, 'Beta'), findsOneWidget);
  });

  testWidgets('archive swipe shows undo toast', (tester) async {
    await tester.pumpWidget(_wrap(notesService));
    await tester.pumpAndSettle();
    final card = find.text('Beta');
    await tester.drag(card, const Offset(-90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Note archived'), findsOneWidget);
  });
}
