import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
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

  test('tags are encrypted, not stored in plaintext', () async {
    final crypto = CryptoService();
    final key = SecretKey(List.generate(32, (i) => i));
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
    final stored = {...note.plainFields(), ...await note.encryptedFields(key, crypto)};
    expect(stored.containsKey('tags'), isFalse);
    expect(stored.values.whereType<String>().any((v) => v.contains('work')), isFalse);

    final roundTrip = await Note.fromData('n1', stored).decryptNote(key, crypto);
    expect(roundTrip.tags, ['work', 'ideas']);
  });
}
