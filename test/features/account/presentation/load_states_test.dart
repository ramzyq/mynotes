import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/account/presentation/account_sheet.dart';
import 'package:mynotes/features/account/presentation/archived_notes_view.dart';
import 'package:mynotes/features/account/presentation/trash_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/backup/backup_view.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = AuthUser(uid: 'u1', email: 'maya@example.com', isEmailVerified: true);
final _offline = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

Note _note(String id, {bool archived = false, DateTime? deletedAt}) => Note(
      id: id,
      title: 'Note $id',
      content: 'x',
      colorIndex: 0,
      isPinned: false,
      isArchived: archived,
      deletedAt: deletedAt,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _app(Widget home, {required Stream<List<Note>> Function() notes}) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_user)),
        notesProvider.overrideWith((ref, uid) => notes()),
        sharedNotesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
        dueCountProvider.overrideWith((ref, uid) => const Stream<int>.empty()),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: home),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('archive and trash', () {
    for (final (name, screen, emptyTitle) in [
      ('archive', const ArchivedNotesView(authUser: _user), 'Nothing archived'),
      ('trash', const TrashView(authUser: _user), 'Trash is empty'),
    ]) {
      testWidgets('$name: loading is not shown as empty', (tester) async {
        final pending = StreamController<List<Note>>();
        addTearDown(pending.close);
        await tester.pumpWidget(_app(screen, notes: () => pending.stream));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(emptyTitle), findsNothing);
      });

      testWidgets('$name: a failed load offers a retry that works', (tester) async {
        var calls = 0;
        await tester.pumpWidget(_app(screen, notes: () {
          calls++;
          return calls == 1 ? Stream.error(_offline) : Stream.value(const <Note>[]);
        }));
        await tester.pumpAndSettle();
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text(emptyTitle), findsNothing);

        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text(emptyTitle), findsOneWidget);
      });
    }
  });

  group('backup', () {
    testWidgets('export stays disabled and says so until notes have loaded', (tester) async {
      final pending = StreamController<List<Note>>();
      addTearDown(pending.close);
      await tester.pumpWidget(_app(const BackupView(authUser: _user), notes: () => pending.stream));
      await tester.pump();

      expect(find.text('Loading your notes…'), findsOneWidget);
      expect(find.textContaining('0 notes'), findsNothing);

      pending.add([_note('a'), _note('b')]);
      await tester.pumpAndSettle();
      expect(find.text('2 notes will be included.'), findsOneWidget);
      expect(find.text('Export 2 notes'), findsOneWidget);
    });

    testWidgets('a failed load explains that nothing can be exported yet', (tester) async {
      await tester.pumpWidget(_app(const BackupView(authUser: _user), notes: () => Stream.error(_offline)));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't load your notes"), findsOneWidget);
    });
  });

  testWidgets('account sheet shows no made-up counts while loading', (tester) async {
    final pending = StreamController<List<Note>>();
    addTearDown(pending.close);
    await tester.pumpWidget(_app(const Scaffold(body: AccountSheet(authUser: _user)), notes: () => pending.stream));
    await tester.pump();
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('Nothing due'), findsNothing);

    pending.add([_note('a', archived: true), _note('b', deletedAt: DateTime.now())]);
    await tester.pump();
    await tester.pump();
    expect(find.text('1'), findsNWidgets(2), reason: 'one archived, one in the trash');
  });
}
