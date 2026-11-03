import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

const uid = 'owner';

Future<(NotesService, FakeFirebaseFirestore)> _service() async {
  final firestore = FakeFirebaseFirestore();
  final crypto = CryptoService();
  final keyManager = KeyManager(crypto: crypto)..setActiveUser(uid);
  await keyManager.generateMasterKey();
  return (NotesService(firestore: firestore, crypto: crypto, keyManager: keyManager), firestore);
}

CollectionReference<Map<String, dynamic>> _notes(FakeFirebaseFirestore db) =>
    db.collection('users').doc(uid).collection('notes');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('createNote stores only ciphertext, and watchNotes decrypts it', () async {
    final (service, db) = await _service();
    final created = await service.createNote(
      uid: uid,
      title: 'Secret title',
      content: 'Secret body',
      colorIndex: 2,
      tags: const ['work'],
    );

    final stored = (await _notes(db).doc(created.id).get()).data()!;
    for (final field in NoteFields.legacyPlaintext) {
      expect(stored.containsKey(field), isFalse, reason: '$field must not be stored in plaintext');
    }
    expect(stored.toString(), isNot(contains('Secret')));
    expect(stored[NoteFields.encryptionVersion], Note.currentEncryptionVersion);

    final notes = await service.watchNotes(uid).first;
    expect(notes.single.title, 'Secret title');
    expect(notes.single.content, 'Secret body');
    expect(notes.single.tags, ['work']);
  });

  test('updateNote re-encrypts the new body', () async {
    final (service, db) = await _service();
    final created = await service.createNote(uid: uid, title: 'v1', content: 'one', colorIndex: 0);
    await service.updateNote(uid: uid, note: created.copyWith(title: 'v2', content: 'two'));

    expect((await _notes(db).doc(created.id).get()).data().toString(), isNot(contains('two')));
    final notes = await service.watchNotes(uid).first;
    expect(notes.single.title, 'v2');
    expect(notes.single.content, 'two');
  });

  test('a PIN lock opens with the right PIN only', () async {
    final (service, db) = await _service();
    final created = await service.createNote(uid: uid, title: 'Locked', content: 'body', colorIndex: 0);
    await service.lockWithPin(uid: uid, note: created, pin: '4821');

    final stored = Note.fromFirestore(await _notes(db).doc(created.id).get());
    expect(stored.pinWrappedKey, isNotNull);
    expect(stored.pinHash, isNull, reason: 'no PIN verifier is stored');

    expect(await service.unlockWithPin(uid: uid, note: stored, pin: '0000'), isNull);
    final opened = await service.unlockWithPin(uid: uid, note: stored, pin: '4821');
    expect(opened?.content, 'body');
  });

  test('deleteExpiredNotes removes only expired notes, with their history', () async {
    final (service, db) = await _service();
    final expired = await service.createNote(
      uid: uid, title: 'gone', content: 'x', colorIndex: 0,
      selfDestructAt: DateTime.now().add(const Duration(milliseconds: 50)),
    );
    final kept = await service.createNote(
      uid: uid, title: 'kept', content: 'x', colorIndex: 0,
      selfDestructAt: DateTime.now().add(const Duration(hours: 1)),
    );
    final forever = await service.createNote(uid: uid, title: 'forever', content: 'x', colorIndex: 0);
    await _notes(db).doc(expired.id).collection('versions').add({'versionNumber': 1});
    await _notes(db).doc(expired.id).collection('comments').add({'authorUid': uid});

    await Future<void>.delayed(const Duration(milliseconds: 100));
    await service.deleteExpiredNotes(uid);

    expect((await _notes(db).doc(expired.id).get()).exists, isFalse);
    expect((await _notes(db).doc(expired.id).collection('versions').get()).size, 0);
    expect((await _notes(db).doc(expired.id).collection('comments').get()).size, 0);
    expect((await _notes(db).doc(kept.id).get()).exists, isTrue);
    expect((await _notes(db).doc(forever.id).get()).exists, isTrue);
  });

  test('watchNotes hides notes past their self-destruct time', () async {
    final (service, db) = await _service();
    final note = await service.createNote(uid: uid, title: 'a', content: 'x', colorIndex: 0);
    await _notes(db).doc(note.id).update({
      NoteFields.selfDestructAt: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 1))),
    });
    expect(await service.watchNotes(uid).first, isEmpty);
  });
}
