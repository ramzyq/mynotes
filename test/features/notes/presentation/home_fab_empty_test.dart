import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/presentation/widgets/empty_state.dart';
import 'package:mynotes/features/notes/presentation/widgets/home_fab.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: Stack(children: [child])));

void main() {
  testWidgets('HomeFab renders label', (tester) async {
    await tester.pumpWidget(_wrap(const HomeFab(onPressed: null)));
    expect(find.text('New note'), findsOneWidget);
  });

  testWidgets('EmptyState shows create button for no query', (tester) async {
    await tester.pumpWidget(_wrap(EmptyState(query: '', activeTag: null, onCreate: () {})));
    expect(find.text('Start writing'), findsOneWidget);
  });

  testWidgets('EmptyState search variant hides create button', (tester) async {
    await tester.pumpWidget(_wrap(EmptyState(query: 'xyz', activeTag: null, onCreate: () {})));
    expect(find.text('Start writing'), findsNothing);
  });
}
