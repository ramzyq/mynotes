import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/collaboration/models/join_request.dart';
import 'package:mynotes/features/collaboration/services/join_link_processor.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/presentation/notes_home_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_card.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';

class _MockNotesService extends Mock implements NotesService {}
class _MockShareService extends Mock implements ShareService {}
class _MockJoinLinkProcessor extends Mock implements JoinLinkProcessor {}

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

Widget _wrap(
  _MockNotesService notesService, {
  required _MockShareService shareService,
  required _MockJoinLinkProcessor joinLinkProcessor,
  Stream<List<Note>> Function()? notes,
  Stream<List<Note>> Function()? shared,
}) =>
    ProviderScope(
      overrides: [
        notesServiceProvider.overrideWithValue(notesService),
        notesProvider.overrideWith((ref, uid) =>
            notes?.call() ?? Stream.value([_n('a', 'Alpha', pinned: true), _n('b', 'Beta', tags: const ['Dev'])])),
        sharedNotesProvider.overrideWith((ref, uid) => shared?.call() ?? Stream.value(const <Note>[])),
        dueCountProvider.overrideWith((ref, uid) => Stream.value(0)),
        shareServiceProvider.overrideWithValue(shareService),
        joinLinkProcessorProvider.overrideWithValue(joinLinkProcessor),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: NotesHomeView(authUser: _user())),
    );

void main() {
  final notesService = _MockNotesService();
  final shareService = _MockShareService();
  final joinLinkProcessor = _MockJoinLinkProcessor();

  setUpAll(() {
    registerFallbackValue(_n('f', 'Fallback'));
    registerFallbackValue('fallback');
  });
  setUp(() {
    when(() => notesService.deleteExpiredNotes(any())).thenAnswer((_) async {});
    when(() => notesService.purgeTrash(any())).thenAnswer((_) async {});
    when(() => notesService.setArchived(uid: any(named: 'uid'), note: any(named: 'note'), archived: any(named: 'archived')))
        .thenAnswer((_) async {});
    when(() => shareService.ensureUserProfile(uid: any(named: 'uid'), email: any(named: 'email'), displayName: any(named: 'displayName')))
        .thenAnswer((_) async {});
    when(() => shareService.watchOwnerJoinRequests(any()))
        .thenAnswer((_) => Stream.value(const <JoinRequest>[]));
    when(() => joinLinkProcessor.processPending())
        .thenAnswer((_) async {});
  });

  testWidgets('renders the header and note cards', (tester) async {
    await tester.pumpWidget(_wrap(notesService, shareService: shareService, joinLinkProcessor: joinLinkProcessor));
    await tester.pumpAndSettle();
    expect(find.textContaining('Maya'), findsWidgets);
    expect(find.text('Alpha'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Beta'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await tester.pumpWidget(_wrap(notesService, shareService: shareService, joinLinkProcessor: joinLinkProcessor));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(NoteCard, 'Alpha'), findsNothing);
    await tester.scrollUntilVisible(find.widgetWithText(NoteCard, 'Beta'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.widgetWithText(NoteCard, 'Beta'), findsOneWidget);
  });

  testWidgets('archive swipe shows undo toast', (tester) async {
    await tester.pumpWidget(_wrap(notesService, shareService: shareService, joinLinkProcessor: joinLinkProcessor));
    await tester.pumpAndSettle();
    final card = find.text('Beta');
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.drag(card, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Note archived'), findsOneWidget);
  });

  group('load states', () {
    Widget wrapWith({Stream<List<Note>> Function()? notes, Stream<List<Note>> Function()? shared}) => _wrap(
          notesService,
          shareService: shareService,
          joinLinkProcessor: joinLinkProcessor,
          notes: notes,
          shared: shared,
        );
    final offline = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

    testWidgets('before the first snapshot it shows loading, not an empty account', (tester) async {
      final pending = StreamController<List<Note>>();
      addTearDown(pending.close);
      await tester.pumpWidget(wrapWith(notes: () => pending.stream));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('A blank page'), findsNothing);
      expect(find.textContaining('0 notes'), findsNothing);
    });

    testWidgets('a failed first load shows an error with a working retry', (tester) async {
      var subscriptions = 0;
      await tester.pumpWidget(wrapWith(notes: () {
        subscriptions++;
        return subscriptions == 1 ? Stream.error(offline) : Stream.value([_n('a', 'Alpha')]);
      }));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your notes"), findsOneWidget);
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.text('A blank page'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(subscriptions, 2);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text("Couldn't load your notes"), findsNothing);
    });

    testWidgets('shared notes failing keeps your own notes and says so', (tester) async {
      await tester.pumpWidget(wrapWith(shared: () => Stream.error(offline)));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text("Couldn't load notes shared with you."), findsOneWidget);
    });

    testWidgets('a real empty account shows the empty state', (tester) async {
      await tester.pumpWidget(wrapWith(notes: () => Stream.value(const <Note>[])));
      await tester.pumpAndSettle();

      expect(find.text('A blank page'), findsOneWidget);
      expect(find.textContaining('0 notes'), findsOneWidget);
    });
  });
}
