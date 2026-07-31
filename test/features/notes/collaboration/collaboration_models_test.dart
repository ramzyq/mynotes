import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/comment.dart';
import 'package:mynotes/features/notes/data/note.dart';

void main() {
  test('Note copyWith preserves and updates collaboration fields', () {
    final base = Note(
      id: 'n1',
      title: 'Title',
      content: 'Content',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    final shared = base.copyWith(
      collaborators: ['uid-a'],
      encryptedKeys: {'uid-a': 'wrapped-key'},
      sharedBy: 'owner-uid',
      sharedAt: DateTime(2024, 1, 2),
    );

    expect(shared.collaborators, ['uid-a']);
    expect(shared.encryptedKeys, {'uid-a': 'wrapped-key'});
    expect(shared.sharedBy, 'owner-uid');
    expect(shared.sharedAt, DateTime(2024, 1, 2));

    expect(base.collaborators, isNull);
    expect(base.sharedBy, isNull);

    final cleared = shared.copyWith(collaborators: null, sharedBy: null);
    expect(cleared.collaborators, isNull);
    expect(cleared.sharedBy, isNull);
  });

  test('Note toMap includes collaboration fields', () {
    final note = Note(
      id: 'n1',
      title: 'Title',
      content: 'Content',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      collaborators: ['uid-a'],
      encryptedKeys: {'uid-a': 'wrapped-key'},
      sharedBy: 'owner-uid',
      sharedAt: DateTime(2024, 1, 2),
    );

    final map = note.toMap();
    expect(map['collaborators'], ['uid-a']);
    expect(map['encryptedKeys'], {'uid-a': 'wrapped-key'});
    expect(map['sharedBy'], 'owner-uid');
    expect(map['sharedAt'], isNotNull);
  });

  test('Comment toMap contains author and content', () {
    final comment = Comment(
      id: 'c1',
      authorUid: 'uid-a',
      authorName: 'Alice',
      content: 'Looks good!',
      createdAt: DateTime(2024, 1, 1),
    );

    final map = comment.toMap();
    expect(map['authorUid'], 'uid-a');
    expect(map['authorName'], 'Alice');
    expect(map['content'], 'Looks good!');
    expect(map['createdAt'], isNotNull);
  });
}
