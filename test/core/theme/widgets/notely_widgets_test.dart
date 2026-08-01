import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/theme/widgets/notely_avatar.dart';
import 'package:mynotes/core/theme/widgets/notely_wordmark.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: child));

void main() {
  testWidgets('TagPill renders its name', (tester) async {
    await tester.pumpWidget(_wrap(const TagPill(name: 'Dev')));
    expect(find.text('Dev'), findsOneWidget);
  });

  testWidgets('NotelyWordmark renders text', (tester) async {
    await tester.pumpWidget(_wrap(const NotelyWordmark()));
    expect(find.text('Notely'), findsOneWidget);
  });

  testWidgets('NotelyAvatar renders initial', (tester) async {
    await tester.pumpWidget(_wrap(const NotelyAvatar(initial: 'M')));
    expect(find.text('M'), findsOneWidget);
  });
}
