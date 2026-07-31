import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/note.dart';

void main() {
  test('Note copyWith preserves and updates tags', () {
    final base = Note(
      id: 'n1',
      title: 'Title',
      content: 'Content',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    expect(base.tags, isNull);

    final tagged = base.copyWith(tags: ['work', 'ideas']);
    expect(tagged.tags, ['work', 'ideas']);
    expect(base.tags, isNull);

    final cleared = tagged.copyWith(tags: null);
    expect(cleared.tags, isNull);
  });

  test('Note toMap includes tags', () {
    final note = Note(
      id: 'n1',
      title: 'Title',
      content: 'Content',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      tags: ['work', 'ideas'],
    );

    final map = note.toMap();
    expect(map['tags'], ['work', 'ideas']);
  });
}
