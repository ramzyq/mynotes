import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/note.dart';

Note _note() => Note(
      id: 'n1',
      title: 'T',
      content: 'C',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

void main() {
  test('isArchived defaults to false', () {
    expect(_note().isArchived, false);
  });

  test('copyWith updates isArchived', () {
    expect(_note().copyWith(isArchived: true).isArchived, true);
  });

  test('toMap round-trips isArchived', () {
    final archived = _note().copyWith(isArchived: true);
    final map = archived.toMap();
    expect(map['isArchived'], true);
  });
}
