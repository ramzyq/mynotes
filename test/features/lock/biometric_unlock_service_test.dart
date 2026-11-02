import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/lock/services/biometric_unlock_service.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _FakeStore implements BiometricKeyStore {
  final items = <String, String>{};
  bool throwOnRead = false;
  int reads = 0;

  @override
  Future<void> write(String name, String value) async => items[name] = value;

  @override
  Future<String?> read(String name) async {
    reads++;
    if (throwOnRead) throw Exception('user cancelled');
    return items[name];
  }

  @override
  Future<void> delete(String name) async => items.remove(name);
}

class _FakePrompter implements BiometricPrompter {
  bool supported = true;
  bool approve = true;
  int prompts = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return approve;
  }
}

const _uid = 'u1';

void main() {
  final crypto = CryptoService();
  final keyManager = KeyManager(crypto: crypto);
  late NotesService notes;
  late _FakeStore store;
  late _FakePrompter prompter;

  /// A PIN-locked note sealed under a random note key wrapped with [kek].
  Future<Note> lockedNote(String id, SecretKey kek) async {
    final noteKey = keyManager.generateNoteKey();
    final plain = Note(
      id: id,
      title: 'Secret plans',
      content: 'Top secret',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    return Note.fromData(id, {
      ...plain.plainFields(),
      ...await plain.encryptedFields(noteKey, crypto),
      NoteFields.isLocked: true,
      NoteFields.pinSalt: 'c2FsdA==',
      NoteFields.pinWrappedKey: await keyManager.wrapKeyWith(
        wrappingKey: kek,
        key: noteKey,
        aad: 'notely:pin:$id',
      ),
    }, ownerUid: _uid);
  }

  BiometricUnlockService service({bool android = true}) => BiometricUnlockService(
        notesService: notes,
        store: store,
        prompter: prompter,
        isAndroid: android,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notes = NotesService(firestore: _MockFirestore(), crypto: crypto, keyManager: keyManager);
    store = _FakeStore();
    prompter = _FakePrompter();
  });

  test('cannot be enabled unless the note was unlocked with its PIN', () async {
    expect(await service().enable(_uid, 'n1'), isFalse);
    expect(store.items, isEmpty);
  });

  test('stores the PIN-derived key and unlocks the note with it later', () async {
    final kek = SecretKey(CryptoService.randomBytes(32));
    final note = await lockedNote('n1', kek);
    // Simulate the PIN unlock that happens before enabling.
    expect(await notes.unlockWithKek(note: note, kek: await kek.extractBytes()), isNotNull);

    final biometrics = service(android: false);
    expect(await biometrics.enable(_uid, 'n1'), isTrue);
    expect(await biometrics.isEnabled(_uid, 'n1'), isTrue);
    notes.relock('n1');

    final result = await biometrics.unlock(_uid, note);
    expect(result, isA<BiometricUnlocked>());
    expect((result as BiometricUnlocked).note.title, 'Secret plans');
    // iOS: the keychain prompts on every read, so no extra prompt.
    expect(prompter.prompts, 0);
  });

  test('on Android every unlock after the first needs a fresh biometric check', () async {
    final kek = SecretKey(CryptoService.randomBytes(32));
    final note = await lockedNote('n1', kek);
    await notes.unlockWithKek(note: note, kek: await kek.extractBytes());
    final biometrics = service();
    await biometrics.enable(_uid, 'n1'); // opens the Keystore-backed store

    prompter.approve = false;
    expect(await biometrics.unlock(_uid, note), isA<BiometricCancelled>());
    expect(store.reads, 0, reason: 'store must not be read without a fresh check');

    prompter.approve = true;
    expect(await biometrics.unlock(_uid, note), isA<BiometricUnlocked>());
    expect(prompter.prompts, 2);
  });

  test('a cancelled prompt keeps biometric unlock enabled', () async {
    final kek = SecretKey(CryptoService.randomBytes(32));
    final note = await lockedNote('n1', kek);
    await notes.unlockWithKek(note: note, kek: await kek.extractBytes());
    final biometrics = service(android: false);
    await biometrics.enable(_uid, 'n1');

    store.throwOnRead = true;
    expect(await biometrics.unlock(_uid, note), isA<BiometricCancelled>());
    expect(await biometrics.isEnabled(_uid, 'n1'), isTrue);
  });

  test('an invalidated item (new fingerprint enrolled) turns biometric unlock off', () async {
    final kek = SecretKey(CryptoService.randomBytes(32));
    final note = await lockedNote('n1', kek);
    await notes.unlockWithKek(note: note, kek: await kek.extractBytes());
    final biometrics = service(android: false);
    await biometrics.enable(_uid, 'n1');

    store.items.clear(); // what the platform does when the key is invalidated
    expect(await biometrics.unlock(_uid, note), isA<BiometricNoLongerAvailable>());
    expect(await biometrics.isEnabled(_uid, 'n1'), isFalse);
  });

  test('a stale key (PIN changed elsewhere) turns biometric unlock off', () async {
    final oldKek = SecretKey(CryptoService.randomBytes(32));
    final oldNote = await lockedNote('n1', oldKek);
    await notes.unlockWithKek(note: oldNote, kek: await oldKek.extractBytes());
    final biometrics = service(android: false);
    await biometrics.enable(_uid, 'n1');

    final rePinned = await lockedNote('n1', SecretKey(CryptoService.randomBytes(32)));
    expect(await biometrics.unlock(_uid, rePinned), isA<BiometricNoLongerAvailable>());
    expect(store.items, isEmpty);
    expect(await biometrics.isEnabled(_uid, 'n1'), isFalse);
  });

  test('prune drops entries for deleted or unlocked notes', () async {
    final kek = SecretKey(CryptoService.randomBytes(32));
    final keep = await lockedNote('keep', kek);
    final gone = await lockedNote('gone', kek);
    final biometrics = service(android: false);
    for (final note in [keep, gone]) {
      await notes.unlockWithKek(note: note, kek: await kek.extractBytes());
      await biometrics.enable(_uid, note.id);
    }

    await biometrics.prune(_uid, [keep]);
    expect(await biometrics.isEnabled(_uid, 'keep'), isTrue);
    expect(await biometrics.isEnabled(_uid, 'gone'), isFalse);
    expect(store.items.keys, ['pin_kek_u1_keep']);
  });

  test('entries are scoped per user', () async {
    final kek = SecretKey(CryptoService.randomBytes(32));
    final note = await lockedNote('n1', kek);
    await notes.unlockWithKek(note: note, kek: await kek.extractBytes());
    final biometrics = service(android: false);
    await biometrics.enable(_uid, 'n1');

    expect(await biometrics.isEnabled('someone-else', 'n1'), isFalse);
    expect(await biometrics.unlock('someone-else', note), isA<BiometricNoLongerAvailable>());
  });
}
