import 'dart:async';
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
    await service.lockWithPin(uid: uid, note: created, pin: '482193');

    final stored = Note.fromFirestore(await _notes(db).doc(created.id).get());
    expect(stored.pinWrappedKey, isNotNull);
    expect(stored.pinHash, isNull, reason: 'no PIN verifier is stored');

    expect(await service.unlockWithPin(uid: uid, note: stored, pin: '000000'), isNull);
    final opened = await service.unlockWithPin(uid: uid, note: stored, pin: '482193');
    expect(opened?.content, 'body');
  });

  test('a new PIN lock needs at least 6 digits', () async {
    final (service, db) = await _service();
    final created = await service.createNote(uid: uid, title: 'Locked', content: 'body', colorIndex: 0);
    for (final pin in ['4821', '12345', 'abcdef', '12 456']) {
      await expectLater(service.lockWithPin(uid: uid, note: created, pin: pin), throwsA(isA<NoteException>()),
          reason: '"$pin" must be refused');
    }
    expect(Note.fromFirestore(await _notes(db).doc(created.id).get()).pinWrappedKey, isNull);
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

  test('moving a note to the trash shows up in the list (no stale cached copy)', () async {
    final (service, _) = await _service();
    final note = await service.createNote(uid: uid, title: 'bin me', content: 'x', colorIndex: 0);
    // Decrypted and cached first, as the open notes list does.
    expect((await service.watchNotes(uid).first).single.isTrashed, isFalse);

    await service.moveToTrash(uid: uid, notes: [note]);
    expect((await service.watchNotes(uid).first).single.isTrashed, isTrue,
        reason: 'only deletedAt changed; the cache must not hide it');

    await service.restoreFromTrash(uid: uid, notes: [note]);
    expect((await service.watchNotes(uid).first).single.isTrashed, isFalse);
  });

  test('watchNotes hides notes past their self-destruct time', () async {
    final (service, db) = await _service();
    final note = await service.createNote(uid: uid, title: 'a', content: 'x', colorIndex: 0);
    await _notes(db).doc(note.id).update({
      NoteFields.selfDestructAt: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 1))),
    });
    expect(await service.watchNotes(uid).first, isEmpty);
  });

  test('an encrypted note whose key is missing is never overwritten', () async {
    final (service, db) = await _service();
    final created = await service.createNote(uid: uid, title: 'keep', content: 'me', colorIndex: 0);
    await _notes(db).doc(created.id).update({NoteFields.wrappedKey: FieldValue.delete()});
    service.clearCaches();
    final before = (await _notes(db).doc(created.id).get()).data()![NoteFields.encryptedContent];

    final listed = (await service.watchNotes(uid).first).single;
    expect(listed.decryptionFailed, isTrue);

    await expectLater(
      service.updateNote(uid: uid, note: created.copyWith(content: 'overwrite')),
      throwsA(isA<NoteException>()),
    );
    final after = (await _notes(db).doc(created.id).get()).data()![NoteFields.encryptedContent];
    expect(after, before);
  });

  test('a study card that becomes due while watching appears without a new snapshot', () async {
    final (service, _) = await _service();
    final card = await service.createNote(uid: uid, title: 'Card', content: 'q', colorIndex: 0, isStudyMaterial: true);
    final dueSoon = DateTime.now().add(const Duration(milliseconds: 300));
    await service.updateStudyProgress(
      uid: uid, noteId: card.id, studyInterval: 1, studyEaseFactor: 2.5, studyRepetitions: 1, studyDueAt: dueSoon,
    );

    final emissions = <List<String>>[];
    final sub = service
        .watchStudyCards(uid, recheck: const Duration(milliseconds: 100))
        .listen((cards) => emissions.add(cards.map((c) => c.id).toList()));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await sub.cancel();

    expect(emissions.first, isEmpty, reason: 'not due yet when first loaded');
    expect(emissions.last, [card.id], reason: 'due now, found by the recheck');
    expect(emissions.where((e) => e.isNotEmpty), hasLength(1), reason: 'no repeat emissions');
  });

  group('committed (offline writes)', () {
    setUp(() => NotesService.ackWait = const Duration(milliseconds: 50));
    tearDown(() => NotesService.ackWait = const Duration(seconds: 3));

    test("a write the server hasn't acknowledged yet doesn't block the caller", () async {
      final neverAcked = Completer<void>();
      final watch = Stopwatch()..start();
      await NotesService.committed(neverAcked.future);
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('a quick rejection still reaches the caller', () async {
      await expectLater(
        NotesService.committed(Future<void>.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'))),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('a rejection after the wait is reported, not thrown', () async {
      final late = Completer<void>();
      await NotesService.committed(late.future);
      late.completeError(StateError('rejected later'));
      await Future<void>.delayed(Duration.zero); // No unhandled error escapes.
    });
  });
}
