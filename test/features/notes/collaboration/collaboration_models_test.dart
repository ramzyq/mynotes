import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
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

  test('Note.fromData parses collaboration fields', () {
    final note = Note.fromData('n1', {
      'encryptionVersion': 2,
      'collaborators': ['uid-a'],
      'encryptedKeys': {'uid-a': 'wrapped-key'},
      'sharedBy': 'owner-uid',
    }, ownerUid: 'owner-uid');
    expect(note.collaborators, ['uid-a']);
    expect(note.encryptedKeys, {'uid-a': 'wrapped-key'});
    expect(note.sharedBy, 'owner-uid');
    expect(note.ownerUid, 'owner-uid');
  });

  test('plainFields never carries sharing or key fields', () {
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
    );
    final map = note.plainFields();
    for (final field in ['collaborators', 'encryptedKeys', 'wrappedKey', 'title', 'content', 'isLocked']) {
      expect(map.containsKey(field), isFalse, reason: field);
    }
  });

  test('Comment body is encrypted and bound to its note and id', () async {
    final crypto = CryptoService();
    final key = SecretKey(List.generate(32, (i) => i));
    final map = await Comment.encryptedMap(
      noteId: 'n1', commentId: 'c1', authorUid: 'uid-a', authorName: 'Alice',
      content: 'Looks good!', noteKey: key, keyGen: 1, crypto: crypto,
    );
    expect(map.containsKey('content'), isFalse);
    expect(map['encryptedContent'], isNot(contains('Looks good')));
    expect(map['authorUid'], 'uid-a');

    Comment sealed(String id) => Comment(
          id: id, authorUid: 'uid-a', authorName: 'Alice',
          encryptedContent: map['encryptedContent'] as String, createdAt: DateTime(2024),
        );
    expect((await sealed('c1').decrypt('n1', key, crypto)).content, 'Looks good!');
    await expectLater(sealed('c2').decrypt('n1', key, crypto), throwsA(anything));
    await expectLater(sealed('c1').decrypt('n2', key, crypto), throwsA(anything));
  });
}
