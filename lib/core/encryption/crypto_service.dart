import 'dart:convert';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final AesGcm _aes = AesGcm.with256bits();
  static const int _saltLength = 32;
  static const int _ivLength = 12;

  /// Derive a 256-bit key from a password using PBKDF2.
  Future<SecretKey> deriveKey({
    required String password,
    required List<int> salt,
    int iterations = 100000,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Generate a random salt for PBKDF2.
  List<int> generateSalt() {
    final salt = Uint8List(_saltLength);
    // Use dart:math Random.secure() or cryptography's secure random
    final random = dart_math.Random.secure();
    for (var i = 0; i < _saltLength; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Encrypt plaintext with AES-256-GCM.
  Future<EncryptedPayload> encrypt({
    required SecretKey key,
    required String plaintext,
  }) async {
    final iv = Uint8List(_ivLength);
    final random = dart_math.Random.secure();
    for (var i = 0; i < _ivLength; i++) {
      iv[i] = random.nextInt(256);
    }

    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: iv,
    );

    return EncryptedPayload(
      ciphertext: secretBox.cipherText,
      nonce: secretBox.nonce,
      mac: secretBox.mac.bytes,
    );
  }

  /// Decrypt ciphertext with AES-256-GCM.
  Future<String> decrypt({
    required SecretKey key,
    required EncryptedPayload payload,
  }) async {
    final secretBox = SecretBox(
      payload.ciphertext,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );

    final plaintext = await _aes.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(plaintext);
  }
}

class EncryptedPayload {
  final List<int> ciphertext;
  final List<int> nonce;
  final List<int> mac;

  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  Map<String, dynamic> toMap() => {
    'ciphertext': base64Encode(ciphertext),
    'nonce': base64Encode(nonce),
    'mac': base64Encode(mac),
  };

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) => EncryptedPayload(
    ciphertext: base64Decode(map['ciphertext'] as String),
    nonce: base64Decode(map['nonce'] as String),
    mac: base64Decode(map['mac'] as String),
  );
}
