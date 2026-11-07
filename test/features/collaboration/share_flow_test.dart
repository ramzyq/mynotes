import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

/// One signed-in user on their own device, sharing a Firestore with others.
class _User {
  _User._(this.uid, this.notes, this.share);
  final String uid;
  final NotesService notes;
  final ShareService share;

  static Future<_User> signIn(FakeFirebaseFirestore db, String uid) async {
    final crypto = CryptoService();
    final keys = KeyManager(crypto: crypto)..setActiveUser(uid);
    await keys.generateMasterKey();
    final notes = NotesService(firestore: db, crypto: crypto, keyManager: keys);
    final share = ShareService(firestore: db, notesService: notes, keyManager: keys, crypto: crypto);
    await share.ensureUserProfile(uid: uid, email: '$uid@example.com');
    return _User._(uid, notes, share);
  }

  /// Read [noteId] of [owner] the way a collaborator's app does.
  Future<String?> read(FakeFirebaseFirestore db, _User owner, String noteId) async {
    final doc = await db.collection('users').doc(owner.uid).collection('notes').doc(noteId).get();
    final sealed = Note.fromFirestore(doc);
    final key = await notes.noteKeyFor(sealed, uid);
    return (await sealed.decryptNote(key, CryptoService())).content;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('a shared note opens for the collaborator', () async {
    final db = FakeFirebaseFirestore();
    final owner = await _User.signIn(db, 'owner');
    final bob = await _User.signIn(db, 'bob');
    final note = await owner.notes.createNote(uid: 'owner', title: 't', content: 'hello', colorIndex: 0);

    await owner.share.shareNote(uid: 'owner', note: note, collaboratorEmail: 'bob@example.com');

    expect(await bob.read(db, owner, note.id), 'hello');
  });

  test('after a removal rotates the key, new collaborators get the new key', () async {
    final db = FakeFirebaseFirestore();
    final owner = await _User.signIn(db, 'owner');
    await _User.signIn(db, 'bob');
    final carol = await _User.signIn(db, 'carol');
    final note = await owner.notes.createNote(uid: 'owner', title: 't', content: 'v1', colorIndex: 0);

    await owner.share.shareNote(uid: 'owner', note: note, collaboratorEmail: 'bob@example.com');
    await owner.share.removeCollaborator(uid: 'owner', note: note, collaboratorUid: 'bob');
    await owner.share.shareNote(uid: 'owner', note: note, collaboratorEmail: 'carol@example.com');

    final doc = await db.collection('users').doc('owner').collection('notes').doc(note.id).get();
    final stored = Note.fromFirestore(doc);
    expect(stored.keyGen, 2);
    expect(stored.collaborators, ['carol']);
    expect(stored.encryptedKeys!.keys, ['carol']);
    expect(await carol.read(db, owner, note.id), 'v1');
  });
}
