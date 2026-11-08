import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';

/// HMAC as Android's javax.crypto has it: an empty key is refused
/// (IllegalArgumentException: Empty key). The app's HMAC on Android is the
/// native one, through cryptography_flutter.
class _StrictHmac extends DartHmac {
  const _StrictHmac(super.hashAlgorithm);

  @override
  Future<Mac> calculateMac(
    List<int> bytes, {
    required SecretKey secretKey,
    List<int> nonce = const <int>[],
    List<int> aad = const <int>[],
  }) async {
    if ((await secretKey.extractBytes()).isEmpty) throw ArgumentError('Empty key');
    return super.calculateMac(bytes, secretKey: secretKey, nonce: nonce, aad: aad);
  }
}

class _AndroidLikeCryptography extends DartCryptography {
  @override
  Hmac hmac(HashAlgorithm hashAlgorithm) => _StrictHmac(hashAlgorithm);
}

void main() {
  final deriver = PasswordSecretDeriver(iterations: 1000);

  // Recorded from the code before the fix: whatever the fix does, every
  // existing account's auth secret and backup key must stay byte-for-byte
  // the same, or nobody could sign in again.
  const vectors = [
    (
      email: 'maya@example.com',
      password: 'correct horse battery',
      authSecret: 'Nt1!9Jn4MkORyu3k-K4AIcsDr8jzwPHUdsNSGt_96Z6Bxlo=',
      backupKey: 'a9rXqA0vL5blrJx9acQTzFstppPb8YCTuNO6Uuy8jnQ=',
    ),
    (
      email: 'Kofi@Example.com',
      password: 'Ɔdɔ yɛ dɛ — café 🔑',
      authSecret: 'Nt1!f-yuOP5C8ut9AF8YoOF7Ajxs60hv-20NSOG5ENRI8JE=',
      backupKey: '2ZacK+Idv4f3ZJohMX2hLcd4cOk+GisrMBo9aCZBuTI=',
    ),
  ];

  group('password secrets', () {
    test('keep their exact values', () async {
      for (final v in vectors) {
        final s = await deriver.derive(email: v.email, password: v.password);
        expect(s.authSecret, v.authSecret, reason: v.email);
        expect(_b64(s.backupKey), v.backupKey, reason: v.email);
      }
    });

    test('work with an HMAC that refuses an empty key, as on Android', () async {
      final previous = Cryptography.instance;
      Cryptography.instance = _AndroidLikeCryptography();
      addTearDown(() => Cryptography.instance = previous);

      for (final v in vectors) {
        final s = await deriver.derive(email: v.email, password: v.password);
        expect(s.authSecret, v.authSecret, reason: 'same keys on Android as everywhere else (${v.email})');
        expect(_b64(s.backupKey), v.backupKey);
      }
    });
  });

  test('HKDF with no salt is the same as with 32 zero bytes (RFC 5869)', () async {
    final hkdf = Hkdf(hmac: DartHmac.sha256(), outputLength: 32);
    final secret = SecretKey(List.generate(32, (i) => i * 7 % 256));
    final info = 'notely-auth-v1'.codeUnits;
    final empty = await (await hkdf.deriveKey(secretKey: secret, nonce: const [], info: info)).extractBytes();
    final zeros = await (await hkdf.deriveKey(secretKey: secret, nonce: List.filled(32, 0), info: info)).extractBytes();
    expect(zeros, empty);
  });

  test('CryptoService.hkdf never hands HMAC an empty key', () async {
    final previous = Cryptography.instance;
    Cryptography.instance = _AndroidLikeCryptography();
    addTearDown(() => Cryptography.instance = previous);
    await expectLater(CryptoService().hkdf(secret: [1, 2, 3], info: 'x'), completes);
  });
}

String _b64(List<int> bytes) => base64Encode(bytes);
