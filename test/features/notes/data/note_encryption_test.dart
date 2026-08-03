import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/features/notes/data/note.dart';

void main() {
  test('encryptNote then decryptNote round-trips title and content', () async {
    final crypto = CryptoService();
    final key = SecretKey(
      List.generate(32, (i) => i),
    );
    final note = Note(
      id: 'n1',
      title: 'Grocery list',
      content: 'Milk, eggs, bread',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    final encrypted = await note.encryptNote(key, crypto);
    expect(encrypted.encryptedTitle, isNotNull);
    expect(encrypted.encryptedContent, isNotNull);

    final decrypted = await encrypted.decryptNote(key, crypto);
    expect(decrypted.title, 'Grocery list');
    expect(decrypted.content, 'Milk, eggs, bread');
  });
}
