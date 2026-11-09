import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

Note _note({String title = 'Groceries', String content = 'eggs'}) => Note(
    id: 'n1',
    title: title,
    content: content,
    colorIndex: 0,
    isPinned: false,
    ownerUid: 'u1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1));

/// Opens the editor on top of a host page so closing it has somewhere to go.
Widget _wrap(_MockNotesService service, {Note? note}) => ProviderScope(
      overrides: [
        notesServiceProvider.overrideWithValue(service),
        notesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
      ],
      child: MaterialApp(
        theme: buildNotelyTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => NoteEditorView(authUser: _user(), note: note),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Finder _titleField() => find.byType(TextField).first;
Finder _bodyField() => find.byType(TextField).at(1);

void _stubCreate(_MockNotesService service) {
  when(() => service.createNote(
        uid: any(named: 'uid'),
        title: any(named: 'title'),
        content: any(named: 'content'),
        colorIndex: any(named: 'colorIndex'),
        isPinned: any(named: 'isPinned'),
        isStudyMaterial: any(named: 'isStudyMaterial'),
        audioAttachments: any(named: 'audioAttachments'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        placeName: any(named: 'placeName'),
        tags: any(named: 'tags'),
        selfDestructAt: any(named: 'selfDestructAt'),
        selfDestructOnRead: any(named: 'selfDestructOnRead'),
      )).thenAnswer((inv) async {
    _creates++;
    return _note(
        title: inv.namedArguments[#title] as String,
        content: inv.namedArguments[#content] as String,
    );
  });
}

/// createNote calls since the last read; reading resets it.
int _creates = 0;
int _createCount(_MockNotesService _) {
  final n = _creates;
  _creates = 0;
  return n;
}

void main() {
  late _MockNotesService service;

  setUpAll(() => registerFallbackValue(_note()));

  setUp(() {
    service = _MockNotesService();
    _creates = 0;
    when(() => service.getBacklinks(any(), any())).thenAnswer((_) async => const <Note>[]);
    when(() => service.searchTitles(any(), any())).thenAnswer((_) async => const <String>[]);
    when(() => service.relock(any())).thenReturn(null);
    _stubCreate(service);
    when(() => service.updateNote(uid: any(named: 'uid'), note: any(named: 'note')))
        .thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester, {Note? note}) async {
    await tester.pumpWidget(_wrap(service, note: note));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a new note is created once after typing stops, then updated', (tester) async {
    await open(tester);

    await tester.enterText(_titleField(), 'Groceries');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(_bodyField(), 'eggs');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(_createCount(service), 1);
    expect(find.text('Saved · encrypted'), findsOneWidget);

    await tester.enterText(_bodyField(), 'eggs, milk');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    final saved = verify(() => service.updateNote(uid: 'u1', note: captureAny(named: 'note')))
        .captured
        .single as Note;
    expect(saved.content, 'eggs, milk');
    expect(_createCount(service), 0);
  });

  testWidgets('back saves pending edits before closing', (tester) async {
    await open(tester, note: _note());

    await tester.enterText(_bodyField(), 'eggs, bread');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    final saved = verify(() => service.updateNote(uid: 'u1', note: captureAny(named: 'note')))
        .captured
        .single as Note;
    expect(saved.content, 'eggs, bread');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('closing an untouched note writes nothing', (tester) async {
    await open(tester, note: _note());

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    verifyNever(() => service.updateNote(uid: any(named: 'uid'), note: any(named: 'note')));
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a blank new note is not created', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(_createCount(service), 0);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('backgrounding the app saves pending edits at once', (tester) async {
    await open(tester, note: _note());

    await tester.enterText(_bodyField(), 'eggs, flour');
    await tester.pump(const Duration(milliseconds: 200));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final saved = verify(() => service.updateNote(uid: 'u1', note: captureAny(named: 'note')))
        .captured
        .single as Note;
    expect(saved.content, 'eggs, flour');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('an editor removed without closing still saves pending edits', (tester) async {
    await open(tester, note: _note());

    await tester.enterText(_bodyField(), 'eggs, salt');
    await tester.pump(const Duration(milliseconds: 200));
    // e.g. sign-out replaces the whole tree before the autosave fires.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    final saved = verify(() => service.updateNote(uid: 'u1', note: captureAny(named: 'note')))
        .captured
        .single as Note;
    expect(saved.content, 'eggs, salt');
  });

  testWidgets('a failed save on close asks before discarding', (tester) async {
    when(() => service.updateNote(uid: any(named: 'uid'), note: any(named: 'note')))
        .thenThrow(Exception('offline'));
    await open(tester, note: _note());

    await tester.enterText(_bodyField(), 'eggs, jam');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsNothing);
    expect(find.text('Not saved'), findsOneWidget);
  });
}
