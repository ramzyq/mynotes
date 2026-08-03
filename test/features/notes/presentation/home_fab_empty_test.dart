import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/presentation/widgets/empty_state.dart';
import 'package:mynotes/features/notes/presentation/widgets/home_fab.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: Stack(children: [child])));

void main() {
  testWidgets('HomeFab renders label', (tester) async {
    await tester.pumpWidget(_wrap(const HomeFab(onPressed: null)));
    expect(find.text('Start writing'), findsOneWidget);
  });

  testWidgets('EmptyState shows subtitle for no query', (tester) async {
    await tester.pumpWidget(_wrap(const EmptyState(query: '', activeTag: null)));
    expect(find.text('A blank page awaits.'), findsOneWidget);
    expect(find.text('Start writing'), findsNothing);
  });

  testWidgets('EmptyState search variant shows no-match copy', (tester) async {
    await tester.pumpWidget(_wrap(const EmptyState(query: 'xyz', activeTag: null)));
    expect(find.text('No notes match "xyz"'), findsOneWidget);
  });
}
