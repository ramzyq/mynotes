import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

Future<KeyManager> _ready(String uid) async {
  final keyManager = KeyManager()..setActiveUser(uid);
  await keyManager.generateMasterKey();
  return keyManager;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('operations fail instead of silently creating a new master key', () async {
    final keyManager = KeyManager()..setActiveUser('u1');
    expect(() => keyManager.createNoteKey('note-1'),
        throwsA(isA<MasterKeyUnavailableException>()));
  });

  test('note key wrap round-trips', () async {
    final keyManager = await _ready('u1');
    final wrapped = await keyManager.createNoteKey('note-1');
    final noteKey = await keyManager.unwrapNoteKey(wrapped);
    expect((await noteKey.extractBytes()).length, 32);
  });

  test('master keys are scoped per user', () async {
    final keyManager = await _ready('alice');
    final aliceKey = await (await keyManager.requireMasterKey()).extractBytes();
    keyManager.setActiveUser('bob');
    expect(await keyManager.hasMasterKey(), isFalse);
    keyManager.setActiveUser('alice');
    expect(await (await keyManager.requireMasterKey()).extractBytes(), aliceKey);
  });

  test('a legacy unscoped key is adopted by the signed-in user', () async {
    FlutterSecureStorage.setMockInitialValues({
      'master_key': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    });
    final keyManager = KeyManager()..setActiveUser('u1');
    expect(await keyManager.hasMasterKey(), isTrue);
    keyManager.setActiveUser('u2');
    expect(await keyManager.hasMasterKey(), isFalse);
  });

  test('derives 256-bit key from password', () async {
    final salt = CryptoService().generateSalt();
    final key = await CryptoService().deriveKey(password: 'test-password', salt: salt);
    expect((await key.extractBytes()).length, 32);
  });

  test('same password with different salt produces different keys', () async {
    final crypto = CryptoService();
    final key1 = await crypto.deriveKey(password: 'password', salt: crypto.generateSalt());
    final key2 = await crypto.deriveKey(password: 'password', salt: crypto.generateSalt());
    expect(await key1.extractBytes(), isNot(equals(await key2.extractBytes())));
  });

  test('getMyPublicKey is deterministic for the same master key', () async {
    final keyManager = await _ready('u1');
    final first = await keyManager.getMyPublicKey();
    keyManager.clearCachedKey();
    expect(await keyManager.getMyPublicKey(), equals(first));
  });

  test('collaborator wrap round-trips between two users', () async {
    final owner = await _ready('owner');
    final noteKey = owner.generateNoteKey();
    final ownerPub = await owner.getMyPublicKey();

    final recipient = await _ready('recipient');
    final recipientPub = await recipient.getMyPublicKey();

    final wrapped = await owner.wrapNoteKeyForCollaborator(
        noteKey: noteKey, recipientPublicKey: recipientPub);
    expect(wrapped, startsWith('v2:'));
    final recovered = await recipient.unwrapCollaboratorNoteKey(
        encryptedKeyStr: wrapped, ownerPublicKey: ownerPub);
    expect(await recovered.extractBytes(), await noteKey.extractBytes());
  });

  test('unwrapping with a different user key fails', () async {
    final owner = await _ready('owner');
    final noteKey = owner.generateNoteKey();
    final ownerPub = await owner.getMyPublicKey();

    final recipient = await _ready('recipient');
    final wrapped = await owner.wrapNoteKeyForCollaborator(
        noteKey: noteKey, recipientPublicKey: await recipient.getMyPublicKey());

    final stranger = await _ready('stranger');
    await expectLater(
      stranger.unwrapCollaboratorNoteKey(encryptedKeyStr: wrapped, ownerPublicKey: ownerPub),
      throwsA(anything),
    );
  });
}
