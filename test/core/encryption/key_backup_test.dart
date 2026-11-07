import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';

/// Mimics Firestore set(merge: true) for the nested `slots` map.
class _MemoryStore implements KeyBackupStore {
  final docs = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String uid) async => docs[uid];

  @override
  Future<void> write(String uid, Map<String, dynamic> data) async {
    final existing = docs[uid] ?? <String, dynamic>{};
    final oldSlots = Map<String, dynamic>.from((existing['slots'] as Map?) ?? const {});
    final newSlots = Map<String, dynamic>.from((data['slots'] as Map?) ?? const {});
    docs[uid] = {...existing, ...data, 'slots': {...oldSlots, ...newSlots}};
  }
}

/// A fresh "device": empty secure storage, same server-side store.
KeyBackupService _device(_MemoryStore store) {
  FlutterSecureStorage.setMockInitialValues({});
  return KeyBackupService(keyManager: KeyManager(), store: store);
}

Future<List<int>> _masterBytes(KeyBackupService service) async =>
    (await service.keyManager.requireMasterKey()).extractBytes();

/// A stand-in for the backup key PasswordSecretDeriver derives from [password].
List<int> _k(String password) => utf8.encode(password.padRight(32, '#')).sublist(0, 32);

const _legacyB64 = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=';

/// A device still holding an older version's unscoped key.
KeyBackupService _legacyDevice(_MemoryStore store, {String? publishedKey}) {
  FlutterSecureStorage.setMockInitialValues({'master_key': _legacyB64});
  return KeyBackupService(
    keyManager: KeyManager(),
    store: store,
    publishedPublicKey: (_) async => publishedKey,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a password slot from an unknown KDF falls back to the recovery code', () async {
    final store = _MemoryStore();
    await _device(store).prepare(uid: 'u1', passwordKey: _k('pw-1'));
    final slots = store.docs['u1']!['slots'] as Map;
    expect((slots['password'] as Map)['kdf'], 'notely-account-v1');
    (slots['password'] as Map)['kdf'] = 'notely-account-v9';

    expect(await _device(store).prepare(uid: 'u1', passwordKey: _k('pw-1')),
        isA<KeySetupNeedsRecoveryCode>());
  });

  test("a device holding the key doesn't downgrade a newer password slot", () async {
    final store = _MemoryStore();
    final device = _device(store);
    await device.prepare(uid: 'u1', passwordKey: _k('pw-1'));
    final slot = (store.docs['u1']!['slots'] as Map)['password'] as Map;
    slot['kdf'] = 'notely-account-v9'; // as a future app version would write it
    final wrapped = slot['wrapped'];

    expect(await device.prepare(uid: 'u1', passwordKey: _k('pw-1')), isA<KeySetupReady>());
    final after = (store.docs['u1']!['slots'] as Map)['password'] as Map;
    expect(after['kdf'], 'notely-account-v9');
    expect(after['wrapped'], wrapped);
  });

  test('what the sign-in server receives cannot open the backup', () async {
    final store = _MemoryStore();
    final secrets = await PasswordSecretDeriver(iterations: 1000)
        .derive(email: 'maya@example.com', password: 'correct horse battery');
    await _device(store).prepare(uid: 'u1', passwordKey: secrets.backupKey);

    // The server holds the backup document and the auth secret. Every key it
    // could make from the auth secret fails; only the device-side key works.
    final authBytes = utf8.encode(secrets.authSecret);
    for (final guess in [authBytes.sublist(0, 32), authBytes.sublist(authBytes.length - 32)]) {
      expect(await _device(store).prepare(uid: 'u1', passwordKey: guess),
          isA<KeySetupNeedsRecoveryCode>());
    }
    expect(await _device(store).prepare(uid: 'u1', passwordKey: secrets.backupKey),
        isA<KeySetupReady>());
    expect(store.docs.toString(), isNot(contains(secrets.authSecret)));
  });

  group('legacy unscoped key', () {
    Future<String> legacyPublicKey() async =>
        base64Encode(await KeyManager().publicKeyForMasterKey(base64Decode(_legacyB64)));

    test('is adopted when it matches the published public key', () async {
      final store = _MemoryStore();
      final service = _legacyDevice(store, publishedKey: await legacyPublicKey());
      await service.prepare(uid: 'u1', passwordKey: _k('pw-1'));
      expect(await _masterBytes(service), base64Decode(_legacyB64));
      expect(await service.keyManager.readLegacyMasterKey(), isNull);
    });

    test("is left alone when it is another account's", () async {
      final store = _MemoryStore();
      final other = base64Encode(List.filled(32, 7));
      final service = _legacyDevice(store, publishedKey: other);
      await service.prepare(uid: 'u2', passwordKey: _k('pw-2'));
      expect(await _masterBytes(service), isNot(base64Decode(_legacyB64)));
      expect(await service.keyManager.readLegacyMasterKey(), isNotNull,
          reason: 'the owner may still need it');
    });

    test('is left alone for an account with no published key, even without a backup', () async {
      // e.g. a new account registering on a device another account used.
      final store = _MemoryStore();
      final service = _legacyDevice(store);
      final result = await service.prepare(uid: 'u3', passwordKey: _k('pw-3'));
      expect(result, isA<KeySetupShowRecoveryCode>(), reason: 'gets a fresh key of its own');
      expect(await _masterBytes(service), isNot(base64Decode(_legacyB64)));
      expect(await service.keyManager.readLegacyMasterKey(), isNotNull);
    });

    test('is not adopted over an existing backup without a published key', () async {
      final store = _MemoryStore();
      await _device(store).prepare(uid: 'u1', passwordKey: _k('pw-1'));
      final service = _legacyDevice(store);
      final result = await service.prepare(uid: 'u1', passwordKey: _k('wrong'));
      expect(result, isA<KeySetupNeedsRecoveryCode>());
    });
  });

  test('first setup creates a key and asks to show a recovery code', () async {
    final store = _MemoryStore();
    final result = await _device(store).prepare(uid: 'u1', passwordKey: _k('pw-1'));
    expect(result, isA<KeySetupShowRecoveryCode>());
    expect((store.docs['u1']!['slots'] as Map).keys, containsAll(['password', 'recovery']));
  });

  test('password sign-in on a new device restores the same master key', () async {
    final store = _MemoryStore();
    final first = _device(store);
    await first.prepare(uid: 'u1', passwordKey: _k('pw-1'));
    final original = await _masterBytes(first);

    final second = _device(store);
    expect(await second.prepare(uid: 'u1', passwordKey: _k('pw-1')), isA<KeySetupReady>());
    expect(await _masterBytes(second), original);
  });

  test('wrong or missing password on a new device needs the recovery code', () async {
    final store = _MemoryStore();
    await _device(store).prepare(uid: 'u1', passwordKey: _k('pw-1'));
    expect(await _device(store).prepare(uid: 'u1', passwordKey: _k('nope')),
        isA<KeySetupNeedsRecoveryCode>());
    expect(await _device(store).prepare(uid: 'u1'), isA<KeySetupNeedsRecoveryCode>());
  });

  test('recovery code restores the key and re-wraps the new password', () async {
    final store = _MemoryStore();
    final first = _device(store);
    final code = (await first.prepare(uid: 'u1', passwordKey: _k('old')) as KeySetupShowRecoveryCode).code;
    final original = await _masterBytes(first);

    final second = _device(store);
    expect(await second.recoverWithCode(uid: 'u1', code: 'WRONG-CODE'), isFalse);
    // Lowercase and missing dashes are tolerated.
    final sloppy = code.toLowerCase().replaceAll('-', ' ');
    expect(await second.recoverWithCode(uid: 'u1', code: sloppy, passwordKey: _k('new')), isTrue);
    expect(await _masterBytes(second), original);

    final third = _device(store);
    expect(await third.prepare(uid: 'u1', passwordKey: _k('new')), isA<KeySetupReady>());
    expect(await _masterBytes(third), original);
  });

  test('existing local key without a backup gets backed up once', () async {
    final store = _MemoryStore();
    final service = _device(store);
    service.keyManager.setActiveUser('u1');
    await service.keyManager.generateMasterKey();
    expect(await service.prepare(uid: 'u1'), isA<KeySetupShowRecoveryCode>());
    expect(await service.prepare(uid: 'u1'), isA<KeySetupReady>());
  });

  test('regenerating the recovery code invalidates the old one', () async {
    final store = _MemoryStore();
    final service = _device(store);
    final oldCode = (await service.prepare(uid: 'u1') as KeySetupShowRecoveryCode).code;
    final newCode = await service.regenerateRecoveryCode('u1');

    expect(await _device(store).recoverWithCode(uid: 'u1', code: oldCode), isFalse);
    expect(await _device(store).recoverWithCode(uid: 'u1', code: newCode), isTrue);
  });

  test('recovery codes are 128-bit and normalize look-alikes', () {
    final code = KeyBackupService.generateRecoveryCode();
    expect(KeyBackupService.normalizeRecoveryCode(code).length, 26);
    expect(KeyBackupService.normalizeRecoveryCode('o1l-i'), '0111');
  });
}
