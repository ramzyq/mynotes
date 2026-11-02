import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/features/notes/data/note.dart';

Note _note({String id = 'n1'}) => Note(
      id: id,
      title: 'Grocery list',
      content: 'Milk, eggs, bread',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      tags: const ['home'],
      latitude: 51.5,
      longitude: -0.12,
      placeName: 'London',
      audioAttachments: const ['/voice/a.m4a'],
    );

void main() {
  final crypto = CryptoService();
  final key = SecretKey(List.generate(32, (i) => i));

  test('encryptNote then decryptNote round-trips body and metadata', () async {
    final encrypted = await _note().encryptNote(key, crypto);
    expect(encrypted.encryptedTitle, isNotNull);
    expect(encrypted.encryptedContent, isNotNull);
    expect(encrypted.encryptionVersion, Note.currentEncryptionVersion);

    final decrypted = await encrypted.decryptNote(key, crypto);
    expect(decrypted.title, 'Grocery list');
    expect(decrypted.content, 'Milk, eggs, bread');
    expect(decrypted.tags, ['home']);
    expect(decrypted.placeName, 'London');
    expect(decrypted.latitude, 51.5);
    expect(decrypted.audioAttachments, ['/voice/a.m4a']);
  });

  // Regression: copyWith(title: null) used to keep the old title, so the
  // "encrypted" note still carried plaintext that was written to Firestore.
  test('encrypted notes carry no plaintext', () async {
    final encrypted = await _note().encryptNote(key, crypto);
    expect(encrypted.title, isNull);
    expect(encrypted.content, isNull);
    expect(encrypted.tags, isNull);
    expect(encrypted.placeName, isNull);
    expect(encrypted.latitude, isNull);

    final stored = {..._note().plainFields(), ...await _note().encryptedFields(key, crypto)};
    for (final field in NoteFields.legacyPlaintext) {
      expect(stored.containsKey(field), isFalse, reason: field);
    }
    final text = stored.values.whereType<String>().join(' ');
    for (final secret in ['Grocery', 'Milk', 'London', 'home', 'voice']) {
      expect(text, isNot(contains(secret)));
    }
  });

  test('ciphertext is bound to its note id (AAD)', () async {
    final fields = await _note(id: 'n1').encryptedFields(key, crypto);
    final moved = Note.fromData('n2', fields);
    await expectLater(moved.decryptNote(key, crypto), throwsA(anything));
  });

  test('title and content ciphertexts cannot be swapped', () async {
    final fields = await _note().encryptedFields(key, crypto);
    final swapped = Note.fromData('n1', {
      ...fields,
      NoteFields.encryptedTitle: fields[NoteFields.encryptedContent],
      NoteFields.encryptedContent: fields[NoteFields.encryptedTitle],
    });
    await expectLater(swapped.decryptNote(key, crypto), throwsA(anything));
  });

  test('legacy v1 notes (no AAD, plaintext metadata) still decrypt', () async {
    final title = await crypto.encrypt(key: key, plaintext: 'Old title');
    final content = await crypto.encrypt(key: key, plaintext: 'Old body');
    final note = Note.fromData('n1', {
      'encryptionVersion': 1,
      'encryptedTitle': title.toBase64(),
      'encryptedContent': content.toBase64(),
      'title': 'LEAKED',
      'tags': ['legacy'],
    });
    expect(note.title, isNull, reason: 'leaked plaintext must not be trusted');
    expect(note.hasLegacyPlaintext, isTrue);
    final plain = await note.decryptNote(key, crypto);
    expect(plain.title, 'Old title');
    expect(plain.content, 'Old body');
    expect(plain.tags, ['legacy']);
  });

  test('copyWith can clear nullable fields', () {
    final locked = _note().copyWith(pinHash: 'h', pinSalt: 's', pinWrappedKey: 'w');
    final cleared = locked.copyWith(pinHash: null, pinSalt: null, pinWrappedKey: null, title: null);
    expect(cleared.pinHash, isNull);
    expect(cleared.pinSalt, isNull);
    expect(cleared.pinWrappedKey, isNull);
    expect(cleared.title, isNull);
    expect(locked.copyWith().pinHash, 'h');
  });

  test('locked and undecryptable notes never preview content', () async {
    expect(_note().copyWith(isLocked: true).previewText, isNot(contains('Milk')));
    final sealed = await _note().encryptNote(key, crypto);
    expect(sealed.copyWith(decryptionFailed: true).displayTitle, isNot(contains('Grocery')));
  });
}
