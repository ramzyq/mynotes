import 'dart:convert';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final AesGcm _aes = AesGcm.with256bits();
  static const int _saltLength = 32;
  static const int _ivLength = 12;

  /// Derive a 256-bit key from a password using PBKDF2-HMAC-SHA256.
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

  /// Derive a 256-bit subkey from high-entropy key material with HKDF-SHA256.
  Future<SecretKey> hkdf({
    required List<int> secret,
    required String info,
    List<int> salt = const [],
  }) {
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
      info: utf8.encode(info),
    );
  }

  /// Generate a random salt for PBKDF2.
  List<int> generateSalt() => randomBytes(_saltLength);

  static Uint8List randomBytes(int length) {
    final random = dart_math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Encrypt plaintext with AES-256-GCM. [aad] is authenticated but not
  /// encrypted; the same value must be supplied to [decrypt].
  Future<EncryptedPayload> encrypt({
    required SecretKey key,
    required String plaintext,
    List<int> aad = const [],
  }) {
    return encryptBytes(key: key, data: utf8.encode(plaintext), aad: aad);
  }

  Future<EncryptedPayload> encryptBytes({
    required SecretKey key,
    required List<int> data,
    List<int> aad = const [],
  }) async {
    final secretBox = await _aes.encrypt(
      data,
      secretKey: key,
      nonce: randomBytes(_ivLength),
      aad: aad,
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
    List<int> aad = const [],
  }) async {
    return utf8.decode(
      await decryptBytes(key: key, payload: payload, aad: aad),
    );
  }

  Future<List<int>> decryptBytes({
    required SecretKey key,
    required EncryptedPayload payload,
    List<int> aad = const [],
  }) {
    final secretBox = SecretBox(
      payload.ciphertext,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );
    return _aes.decrypt(secretBox, secretKey: key, aad: aad);
  }

  /// Encrypt [data] and return the compact base64 `ciphertext|nonce|mac` form.
  Future<String> seal({
    required SecretKey key,
    required List<int> data,
    String aad = '',
  }) async {
    final payload = await encryptBytes(key: key, data: data, aad: utf8.encode(aad));
    return payload.toBase64();
  }

  /// Inverse of [seal].
  Future<List<int>> open({
    required SecretKey key,
    required String sealed,
    String aad = '',
  }) {
    return decryptBytes(
      key: key,
      payload: EncryptedPayload.fromBase64(sealed),
      aad: utf8.encode(aad),
    );
  }
}

class EncryptedPayload {
  static const int nonceLength = 12;
  static const int macLength = 16;

  final List<int> ciphertext;
  final List<int> nonce;
  final List<int> mac;

  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  /// Parse the compact `ciphertext|nonce|mac` byte layout used for storage.
  factory EncryptedPayload.fromCombined(List<int> combined) {
    if (combined.length < nonceLength + macLength) {
      throw const FormatException('Encrypted payload is too short');
    }
    final macStart = combined.length - macLength;
    final nonceStart = macStart - nonceLength;
    return EncryptedPayload(
      ciphertext: combined.sublist(0, nonceStart),
      nonce: combined.sublist(nonceStart, macStart),
      mac: combined.sublist(macStart),
    );
  }

  factory EncryptedPayload.fromBase64(String value) =>
      EncryptedPayload.fromCombined(base64Decode(value));

  List<int> toCombined() => [...ciphertext, ...nonce, ...mac];

  String toBase64() => base64Encode(toCombined());

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
