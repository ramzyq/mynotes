import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

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
  return KeyBackupService(keyManager: KeyManager(), store: store, passwordIterations: 1000);
}

Future<List<int>> _masterBytes(KeyBackupService service) async =>
    (await service.keyManager.requireMasterKey()).extractBytes();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first setup creates a key and asks to show a recovery code', () async {
    final store = _MemoryStore();
    final result = await _device(store).prepare(uid: 'u1', password: 'pw-1');
    expect(result, isA<KeySetupShowRecoveryCode>());
    expect((store.docs['u1']!['slots'] as Map).keys, containsAll(['password', 'recovery']));
  });

  test('password sign-in on a new device restores the same master key', () async {
    final store = _MemoryStore();
    final first = _device(store);
    await first.prepare(uid: 'u1', password: 'pw-1');
    final original = await _masterBytes(first);

    final second = _device(store);
    expect(await second.prepare(uid: 'u1', password: 'pw-1'), isA<KeySetupReady>());
    expect(await _masterBytes(second), original);
  });

  test('wrong or missing password on a new device needs the recovery code', () async {
    final store = _MemoryStore();
    await _device(store).prepare(uid: 'u1', password: 'pw-1');
    expect(await _device(store).prepare(uid: 'u1', password: 'nope'),
        isA<KeySetupNeedsRecoveryCode>());
    expect(await _device(store).prepare(uid: 'u1'), isA<KeySetupNeedsRecoveryCode>());
  });

  test('recovery code restores the key and re-wraps the new password', () async {
    final store = _MemoryStore();
    final first = _device(store);
    final code = (await first.prepare(uid: 'u1', password: 'old') as KeySetupShowRecoveryCode).code;
    final original = await _masterBytes(first);

    final second = _device(store);
    expect(await second.recoverWithCode(uid: 'u1', code: 'WRONG-CODE'), isFalse);
    // Lowercase and missing dashes are tolerated.
    final sloppy = code.toLowerCase().replaceAll('-', ' ');
    expect(await second.recoverWithCode(uid: 'u1', code: sloppy, password: 'new'), isTrue);
    expect(await _masterBytes(second), original);

    final third = _device(store);
    expect(await third.prepare(uid: 'u1', password: 'new'), isA<KeySetupReady>());
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
