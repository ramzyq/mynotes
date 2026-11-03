import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/features/backup/backup_service.dart';
import 'package:mynotes/features/notes/data/note.dart';

Note _note(String id, {String title = 'Groceries', String content = 'eggs, milk', DateTime? deletedAt, bool locked = false}) => Note(
      id: id,
      title: title,
      content: content,
      colorIndex: 2,
      isPinned: true,
      tags: const ['Home'],
      reminderAt: DateTime.utc(2026, 12, 1, 9),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      deletedAt: deletedAt,
      isLocked: locked,
      encryptedTitle: locked ? 'sealed' : null,
      encryptionVersion: locked ? 2 : 0,
    );

void main() {
  // Few iterations keep the test fast; the format records the count used.
  final service = BackupService(crypto: CryptoService(), iterations: 1000);

  test('round-trips notes and their metadata', () async {
    final file = await service.encode([_note('a')], 'correct horse');
    final notes = await service.decode(file, 'correct horse');

    expect(notes, hasLength(1));
    final n = notes.single;
    expect(n.title, 'Groceries');
    expect(n.content, 'eggs, milk');
    expect(n.tags, ['Home']);
    expect(n.colorIndex, 2);
    expect(n.isPinned, isTrue);
    expect(n.reminderAt!.toUtc(), DateTime.utc(2026, 12, 1, 9));
    expect(n.createdAt.toUtc(), DateTime.utc(2026, 1, 1));
  });

  test('the file reveals nothing without the password', () async {
    final file = await service.encode([_note('a', title: 'Secret plan')], 'correct horse');
    expect(file, isNot(contains('Secret plan')));
    expect(file, isNot(contains('eggs')));
    expect(jsonDecode(file)['format'], BackupService.format);
  });

  test('rejects a wrong password', () async {
    final file = await service.encode([_note('a')], 'correct horse');
    expect(() => service.decode(file, 'wrong horse!'), throwsA(isA<BackupException>()));
  });

  test('rejects a tampered header', () async {
    final file = jsonDecode(await service.encode([_note('a')], 'correct horse')) as Map<String, dynamic>;
    file['kdf']['iterations'] = 999;
    expect(() => service.decode(jsonEncode(file), 'correct horse'), throwsA(isA<BackupException>()));
  });

  test('rejects files that are not backups and short passwords', () async {
    expect(() => service.decode('{"hello": 1}', 'x'), throwsA(isA<BackupException>()));
    expect(() => service.decode('not json', 'x'), throwsA(isA<BackupException>()));
    expect(() => service.encode([_note('a')], 'short'), throwsA(isA<BackupException>()));
  });

  test('exports live, readable notes only', () {
    final notes = [
      _note('live'),
      _note('trashed', deletedAt: DateTime.now()),
      _note('locked', locked: true),
    ];
    expect(BackupService.exportable(notes).map((n) => n.id), ['live']);
  });
}
