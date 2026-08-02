import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';

Note _n(String id, {DateTime? updated, DateTime? created, String? title, List<String>? tags}) =>
    Note(
      id: id,
      title: title,
      content: 'c',
      colorIndex: 0,
      isPinned: false,
      createdAt: created ?? DateTime(2024, 1, 1),
      updatedAt: updated ?? DateTime(2024, 1, 1),
      tags: tags,
    );

void main() {
  test('updated sorts newest first', () {
    final list = [_n('a', updated: DateTime(2024, 1, 2)), _n('b', updated: DateTime(2024, 1, 1))];
    list.sort(noteComparator(NoteSort.updated));
    expect(list.first.id, 'a');
  });

  test('created sorts by createdAt', () {
    final list = [_n('a', created: DateTime(2024, 1, 1)), _n('b', created: DateTime(2024, 1, 2))];
    list.sort(noteComparator(NoteSort.created));
    expect(list.first.id, 'b');
  });

  test('titleAZ sorts alphabetically case-insensitive', () {
    final list = [_n('a', title: 'Banana'), _n('b', title: 'apple')];
    list.sort(noteComparator(NoteSort.titleAZ));
    expect(list.first.id, 'b');
  });

  test('tag sorts by first tag then title', () {
    final list = [
      _n('a', title: 'Zebra', tags: ['Dev']),
      _n('b', title: 'Alpha', tags: ['Career']),
    ];
    list.sort(noteComparator(NoteSort.tag));
    expect(list.first.id, 'b');
  });
}
