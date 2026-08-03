import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('createNoteKey does not require a pre-initialized master key', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final keyManager = KeyManager();
    final wrapped = await keyManager.createNoteKey('note-1');
    final noteKey = await keyManager.unwrapNoteKey(wrapped);
    final bytes = await noteKey.extractBytes();
    expect(bytes.length, equals(32));
  });
  test('derives 256-bit key from password', () async {
    final salt = CryptoService().generateSalt();
    final key = await CryptoService().deriveKey(password: 'test-password', salt: salt);
    final extracted = await key.extractBytes();
    expect(extracted.length, equals(32));
  });

  test('same password with different salt produces different keys', () async {
    final crypto = CryptoService();
    final salt1 = crypto.generateSalt();
    final salt2 = crypto.generateSalt();
    final key1 = await crypto.deriveKey(password: 'password', salt: salt1);
    final key2 = await crypto.deriveKey(password: 'password', salt: salt2);
    final bytes1 = await key1.extractBytes();
    final bytes2 = await key2.extractBytes();
    expect(bytes1, isNot(equals(bytes2)));
  });

  test('different password with same salt produces different keys', () async {
    final crypto = CryptoService();
    final salt = crypto.generateSalt();
    final key1 = await crypto.deriveKey(password: 'password-a', salt: salt);
    final key2 = await crypto.deriveKey(password: 'password-b', salt: salt);
    final bytes1 = await key1.extractBytes();
    final bytes2 = await key2.extractBytes();
    expect(bytes1, isNot(equals(bytes2)));
  });
}
