import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/widgets/pinned_note_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildNotelyTheme(Brightness.light),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 210,
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );

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

PinnedNoteCard _card({Note? note, bool selectMode = false, bool selected = false, VoidCallback? onOpen, VoidCallback? onSelect, VoidCallback? onUnpin, VoidCallback? onArchive}) {
  return PinnedNoteCard(
    note: note ?? _note(),
    relativeTime: '2d ago',
    selectMode: selectMode,
    selected: selected,
    onOpen: onOpen ?? () {},
    onSelect: onSelect ?? () {},
    onUnpin: onUnpin ?? () {},
    onArchive: onArchive ?? () {},
  );
}

void main() {
  testWidgets('renders pill, title, snippet, and timestamp', (tester) async {
    await tester.pumpWidget(_wrap(_card()));
    expect(find.text('Dev'), findsOneWidget);
    expect(find.text('Flutter state management'), findsOneWidget);
    expect(find.text('2d ago'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('untagged note shows a General pill', (tester) async {
    await tester.pumpWidget(_wrap(_card(note: _note().copyWith(tags: null))));
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('tap opens the note when not in select mode', (tester) async {
    var opened = false;
    await tester.pumpWidget(_wrap(_card(onOpen: () => opened = true)));
    await tester.tap(find.text('Flutter state management'));
    expect(opened, true);
  });

  testWidgets('overflow menu can unpin', (tester) async {
    var unpinned = false;
    await tester.pumpWidget(_wrap(_card(onUnpin: () => unpinned = true)));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin'));
    expect(unpinned, true);
  });

  testWidgets('select mode toggles selection instead of opening', (tester) async {
    var selected = false;
    await tester.pumpWidget(_wrap(_card(selectMode: true, onSelect: () => selected = true)));
    await tester.tap(find.text('Flutter state management'));
    expect(selected, true);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
