import 'dart:convert';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';

class KeyManager {
  final CryptoService _crypto = CryptoService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _masterKeyKey = 'master_key';
  static const _saltKey = 'key_salt';
  static const _keyVersion = 1;

  SecretKey? _cachedMasterKey;

  /// Derive and persist the Master Key on first login.
  Future<void> initializeMasterKey(String password) async {
    final salt = _crypto.generateSalt();
    final masterKey = await _crypto.deriveKey(
      password: password,
      salt: salt,
    );

    // Store salt and a key-wrapped version for later re-derivation
    final masterKeyBytes = await masterKey.extractBytes();
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    // Store the key material (wrapped with itself for persistence)
    // Alternative: store salt only and re-derive on each login
    await _storage.write(
      key: _masterKeyKey,
      value: base64Encode(masterKeyBytes),
    );

    _cachedMasterKey = masterKey;
  }

  /// Load Master Key from secure storage (called on app start / login).
  Future<SecretKey?> loadMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey;

    final keyBytes = await _storage.read(key: _masterKeyKey);
    if (keyBytes == null) return null;

    _cachedMasterKey = SecretKey(base64Decode(keyBytes));
    return _cachedMasterKey;
  }

  /// Generate a new random Note Key and wrap it with the Master Key.
  Future<Map<String, String>> createNoteKey(String noteId) async {
    final masterKey = await loadMasterKey();
    if (masterKey == null) throw Exception('Master Key not initialized');

    // Generate random Note Key
    final noteKey = SecretKey(Uint8List.fromList(
      List.generate(32, (_) => dart_math.Random.secure().nextInt(256)),
    ));

    // Wrap Note Key with Master Key
    final noteKeyBytes = await noteKey.extractBytes();
    final encrypted = await _crypto.encrypt(
      key: masterKey,
      plaintext: base64Encode(noteKeyBytes),
    );

    return {
      '$_keyVersion': base64Encode(encrypted.ciphertext + encrypted.nonce + encrypted.mac),
    };
  }

  /// Unwrap a Note Key using the Master Key.
  Future<SecretKey> unwrapNoteKey(Map<String, String> wrappedKeyData) async {
    final masterKey = await loadMasterKey();
    if (masterKey == null) throw Exception('Master Key not initialized');

    // Find latest version
    final wrappedKeyStr = wrappedKeyData['$_keyVersion'];
    if (wrappedKeyStr == null) throw Exception('No key version $_keyVersion');

    final combined = base64Decode(wrappedKeyStr);
    final payload = EncryptedPayload(
      ciphertext: combined.sublist(0, combined.length - 24),
      nonce: combined.sublist(combined.length - 24, combined.length - 12),
      mac: combined.sublist(combined.length - 12),
    );

    final noteKeyStr = await _crypto.decrypt(key: masterKey, payload: payload);
    return SecretKey(base64Decode(noteKeyStr));
  }

  /// Clear Master Key from memory (on app background).
  void clearCachedKey() {
    _cachedMasterKey = null;
  }

  /// Check if a Master Key exists (user has set up encryption).
  Future<bool> hasMasterKey() async {
    return await _storage.read(key: _masterKeyKey) != null;
  }
}
