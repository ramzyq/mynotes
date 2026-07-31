import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';

void main() {
  late CryptoService crypto;

  setUp(() {
    crypto = CryptoService();
  });

  test('encrypt and decrypt round-trip', () async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKey(password: 'test-password', salt: salt);
    const original = 'Hello, encrypted world!';

    final encrypted = await crypto.encrypt(key: key, plaintext: original);
    final decrypted = await crypto.decrypt(key: key, payload: encrypted);

    expect(decrypted, equals(original));
  });

  test('wrong key fails decryption', () async {
    final salt = crypto.generateSalt();
    final key1 = await crypto.deriveKey(password: 'password1', salt: salt);
    final key2 = await crypto.deriveKey(password: 'password2', salt: salt);
    const original = 'Secret data';

    final encrypted = await crypto.encrypt(key: key1, plaintext: original);
    // Should throw when decrypting with wrong key
    try {
      await crypto.decrypt(key: key2, payload: encrypted);
      fail('Expected exception when decrypting with wrong key');
    } catch (_) {
      // Expected
    }
  });

  test('encrypted payload toMap/fromMap round-trip', () {
    final payload = EncryptedPayload(
      ciphertext: [1, 2, 3],
      nonce: [4, 5, 6],
      mac: [7, 8, 9],
    );

    final map = payload.toMap();
    final restored = EncryptedPayload.fromMap(map);

    expect(restored.ciphertext, equals(payload.ciphertext));
    expect(restored.nonce, equals(payload.nonce));
    expect(restored.mac, equals(payload.mac));
  });
}
