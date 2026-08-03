// test/features/notes/presentation/note_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_card.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: child));

Note _note() => Note(
      id: 'n1',
      title: 'Flutter state management',
      content: 'Riverpod wins on compile-time safety.',
      colorIndex: 0,
      isPinned: true,
      tags: const ['Dev', 'Projects'],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
    );

void main() {
  testWidgets('renders title, preview, tags, and time', (tester) async {
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note(),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () {},
      onTagTap: (_) {},
      relativeTime: '12 min',
    )));
    expect(find.text('Flutter state management'), findsOneWidget);
    expect(find.text('Dev'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
  });

  testWidgets('tap calls onOpen when not in select mode', (tester) async {
    var opened = false;
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note(),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () => opened = true,
      onTagTap: (_) {},
      relativeTime: '1 h',
    )));
    await tester.tap(find.text('Flutter state management'));
    expect(opened, true);
  });

  testWidgets('swiping left reveals archive action', (tester) async {
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note(),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () {},
      onTagTap: (_) {},
      relativeTime: '1 h',
    )));
    await tester.drag(find.byType(NoteCard), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('shows location pin and place name when present', (tester) async {
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note().copyWith(latitude: 30.0, longitude: 31.2, placeName: 'Downtown Cairo'),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () {},
      onTagTap: (_) {},
      relativeTime: '1 h',
    )));
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.text('Downtown Cairo'), findsOneWidget);
  });

  testWidgets('shows location pin only when coords exist without a name', (tester) async {
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note().copyWith(latitude: 30.0, longitude: 31.2),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () {},
      onTagTap: (_) {},
      relativeTime: '1 h',
    )));
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
  });

  testWidgets('hides location row when note has no coords', (tester) async {
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note(),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () {},
      onTagTap: (_) {},
      relativeTime: '1 h',
    )));
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
  });
}
