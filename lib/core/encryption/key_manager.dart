import 'dart:convert';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/sharing_keys.dart';

class KeyManager {
  final CryptoService _crypto = CryptoService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final SharingKeys _sharing = SharingKeys();
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

  /// Load an existing Master Key, or generate and persist one on first use.
  Future<SecretKey> ensureMasterKey() async {
    final existing = await loadMasterKey();
    if (existing != null) return existing;

    final bytes = Uint8List.fromList(
      List.generate(32, (_) => dart_math.Random.secure().nextInt(256)),
    );
    final masterKey = SecretKey(bytes);
    await _storage.write(key: _masterKeyKey, value: base64Encode(bytes));
    _cachedMasterKey = masterKey;
    return masterKey;
  }

  /// Generate a new random Note Key and wrap it with the Master Key.
  Future<Map<String, String>> createNoteKey(String noteId) async {
    final masterKey = await ensureMasterKey();

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
    final masterKey = await ensureMasterKey();

    // Find latest version
    final wrappedKeyStr = wrappedKeyData['$_keyVersion'];
    if (wrappedKeyStr == null) throw Exception('No key version $_keyVersion');

    final combined = base64Decode(wrappedKeyStr);
    final payload = _splitPayload(combined);

    final noteKeyStr = await _crypto.decrypt(key: masterKey, payload: payload);
    return SecretKey(base64Decode(noteKeyStr));
  }

  static EncryptedPayload _splitPayload(Uint8List combined) {
    final nonceLength = 12;
    final macLength = 16;
    return EncryptedPayload(
      ciphertext: combined.sublist(0, combined.length - nonceLength - macLength),
      nonce: combined.sublist(
        combined.length - nonceLength - macLength,
        combined.length - macLength,
      ),
      mac: combined.sublist(combined.length - macLength),
    );
  }

  /// Clear Master Key from memory (on app background).
  void clearCachedKey() {
    _cachedMasterKey = null;
  }

  /// Check if a Master Key exists (user has set up encryption).
  Future<bool> hasMasterKey() async {
    return await _storage.read(key: _masterKeyKey) != null;
  }

  /// Encrypt a note key so only the owner of [recipientPublicKey] can unwrap it.
  Future<String> wrapNoteKeyForCollaborator({
    required SecretKey noteKey,
    required List<int> recipientPublicKey,
  }) async {
    final sharedSecret = await _ecdhSharedSecret(recipientPublicKey);
    final noteKeyBytes = await noteKey.extractBytes();
    final encrypted = await _crypto.encrypt(
      key: sharedSecret,
      plaintext: base64Encode(noteKeyBytes),
    );
    final combined = encrypted.ciphertext + encrypted.nonce + encrypted.mac;
    return base64Encode(combined);
  }

  /// Decrypt a note key that was wrapped for us by the owner of [ownerPublicKey].
  Future<SecretKey> unwrapCollaboratorNoteKey({
    required String encryptedKeyStr,
    required List<int> ownerPublicKey,
  }) async {
    final sharedSecret = await _ecdhSharedSecret(ownerPublicKey);
    final combined = base64Decode(encryptedKeyStr);
    final payload = _splitPayload(combined);
    final noteKeyStr = await _crypto.decrypt(key: sharedSecret, payload: payload);
    return SecretKey(base64Decode(noteKeyStr));
  }

  /// Deterministic X25519 keypair derived from this device's master key.
  Future<SimpleKeyPair> _loadMyKeyPair() async {
    final masterKey = await ensureMasterKey();
    final masterBytes = await masterKey.extractBytes();
    return _sharing.keyPairFromMasterKey(masterBytes);
  }

  Future<SecretKey> _ecdhSharedSecret(List<int> remotePublicKey) async {
    return _sharing.sharedSecret(
      myKeyPair: await _loadMyKeyPair(),
      remotePublicKey: remotePublicKey,
    );
  }

  /// This user's X25519 public key (32 bytes), derived deterministically
  /// from the master key.
  Future<Uint8List> getMyPublicKey() async {
    final keyPair = await _loadMyKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }
}
