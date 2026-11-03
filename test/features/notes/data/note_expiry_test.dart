import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/note.dart';

Note _n(String id, {DateTime? selfDestructAt}) => Note(
      id: id,
      title: 't',
      content: 'c',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      selfDestructAt: selfDestructAt,
    );

void main() {
  final now = DateTime(2026, 11, 3, 12);

  test('nextExpiry picks the earliest future self-destruct time', () {
    final notes = [
      _n('never'),
      _n('past', selfDestructAt: now.subtract(const Duration(minutes: 1))),
      _n('later', selfDestructAt: now.add(const Duration(hours: 2))),
      _n('soon', selfDestructAt: now.add(const Duration(minutes: 5))),
    ];
    expect(Note.nextExpiry(notes, now: now), now.add(const Duration(minutes: 5)));
  });

  test('nextExpiry is null when nothing is pending', () {
    expect(Note.nextExpiry([_n('a'), _n('b', selfDestructAt: now)], now: now), isNull);
    expect(Note.nextExpiry(const <Note>[], now: now), isNull);
  });

  test('isExpired is true at and after the self-destruct time', () {
    expect(_n('a', selfDestructAt: DateTime.now().subtract(const Duration(seconds: 1))).isExpired, isTrue);
    expect(_n('b', selfDestructAt: DateTime.now().add(const Duration(hours: 1))).isExpired, isFalse);
    expect(_n('c').isExpired, isFalse);
  });
}
