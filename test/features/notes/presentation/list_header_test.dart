import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';
import 'package:mynotes/features/notes/presentation/widgets/list_header.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: child));

void main() {
  testWidgets('header shows personalized serif title', (tester) async {
    await tester.pumpWidget(_wrap(ListHeader(
      userName: 'Maya',
      noteCount: 3,
      onOpenAccount: () {},
      onToggleSelect: () {},
      selectMode: false,
    )));
    expect(find.textContaining('Maya'), findsOneWidget);
  });

  testWidgets('filter chips respond to taps', (tester) async {
    String? chosen;
    await tester.pumpWidget(_wrap(FilterChips(active: 'All', pinnedCount: 1, onChanged: (v) => chosen = v)));
    await tester.tap(find.text('Recent'));
    expect(chosen, 'Recent');
  });

  testWidgets('sort menu opens and selects', (tester) async {
    NoteSort? chosen;
    await tester.pumpWidget(_wrap(SortMenu(sort: NoteSort.updated, onChanged: (v) => chosen = v)));
    await tester.tap(find.text('Updated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title (A–Z)'));
    expect(chosen, NoteSort.titleAZ);
  });
}
