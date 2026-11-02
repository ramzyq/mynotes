import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/sharing_keys.dart';

/// Thrown when an operation needs the master key but it has not been set up
/// or recovered on this device yet (see `KeyBackupService.prepare`).
class MasterKeyUnavailableException implements Exception {
  const MasterKeyUnavailableException();
  @override
  String toString() => 'Encryption key is not available on this device yet.';
}

/// Owns the user's master key and every key-wrapping operation.
///
/// Key hierarchy:
///   master key (32 random bytes, per user, backed up via KeyBackupService)
///     -> note keys (one per note, wrapped with the master key)
///     -> X25519 sharing keypair (derived from the master key)
class KeyManager {
  KeyManager({FlutterSecureStorage? storage, CryptoService? crypto})
      : _storage = storage ?? const FlutterSecureStorage(),
        _crypto = crypto ?? CryptoService();

  final CryptoService _crypto;
  final FlutterSecureStorage _storage;
  final SharingKeys _sharing = SharingKeys();

  static const _legacyMasterKeyKey = 'master_key';
  static const _legacySaltKey = 'key_salt';
  static const _noteKeyVersion = 1;
  static const _sharePrefixV2 = 'v2:';

  String? _uid;
  SecretKey? _cachedMasterKey;
  SimpleKeyPair? _cachedKeyPair;

  String? get activeUid => _uid;

  String _masterKeyKey(String uid) => 'master_key_$uid';

  /// Scope all key operations to [uid]. Passing null (sign-out) or a
  /// different user clears every cached key from memory.
  void setActiveUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    clearCachedKey();
  }

  /// Clear key material from memory.
  void clearCachedKey() {
    _cachedMasterKey = null;
    _cachedKeyPair = null;
  }

  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw const MasterKeyUnavailableException();
    return uid;
  }

  /// Load this user's master key from secure storage, adopting a key stored
  /// by an older app version (which kept a single unscoped key) if present.
  Future<SecretKey?> loadMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey;
    final uid = _uid;
    if (uid == null) return null;

    var stored = await _storage.read(key: _masterKeyKey(uid));
    if (stored == null) {
      final legacy = await _storage.read(key: _legacyMasterKeyKey);
      if (legacy != null) {
        await _storage.write(key: _masterKeyKey(uid), value: legacy);
        await _storage.delete(key: _legacyMasterKeyKey);
        await _storage.delete(key: _legacySaltKey);
        stored = legacy;
      }
    }
    if (stored == null) return null;
    _cachedMasterKey = SecretKey(base64Decode(stored));
    return _cachedMasterKey;
  }

  Future<bool> hasMasterKey() async => await loadMasterKey() != null;

  /// The master key, or [MasterKeyUnavailableException] if it is not set up.
  /// Never silently creates a new key: doing so would orphan existing notes.
  Future<SecretKey> requireMasterKey() async {
    final key = await loadMasterKey();
    if (key == null) throw const MasterKeyUnavailableException();
    return key;
  }

  /// Persist [bytes] as this user's master key (first setup or recovery).
  Future<void> storeMasterKey(List<int> bytes) async {
    final uid = _requireUid();
    await _storage.write(key: _masterKeyKey(uid), value: base64Encode(bytes));
    clearCachedKey();
    _cachedMasterKey = SecretKey(List<int>.from(bytes));
  }

  /// Generate and persist a brand-new master key. Only call this when the
  /// user has no backup anywhere (first ever setup).
  Future<List<int>> generateMasterKey() async {
    final bytes = CryptoService.randomBytes(32);
    await storeMasterKey(bytes);
    return bytes;
  }

  // ---------------------------------------------------------------- note keys

  /// Generate a random note key.
  SecretKey generateNoteKey() => SecretKey(CryptoService.randomBytes(32));

  /// Wrap [noteKey] with the master key for storage on the note document.
  Future<Map<String, String>> wrapNoteKey(SecretKey noteKey) async {
    final masterKey = await requireMasterKey();
    final encrypted = await _crypto.encrypt(
      key: masterKey,
      plaintext: base64Encode(await noteKey.extractBytes()),
    );
    return {'$_noteKeyVersion': encrypted.toBase64()};
  }

  /// Generate a new note key and return it wrapped with the master key.
  Future<Map<String, String>> createNoteKey(String noteId) async {
    return wrapNoteKey(generateNoteKey());
  }

  /// Unwrap a note key using the master key. Uses the newest supported
  /// wrapping version present in [wrappedKeyData].
  Future<SecretKey> unwrapNoteKey(Map<String, String> wrappedKeyData) async {
    final masterKey = await requireMasterKey();
    final versions = wrappedKeyData.keys
        .map(int.tryParse)
        .whereType<int>()
        .where((v) => v <= _noteKeyVersion)
        .toList()
      ..sort();
    if (versions.isEmpty) {
      throw const FormatException('No supported note key version');
    }
    final wrapped = wrappedKeyData['${versions.last}']!;
    final noteKeyStr = await _crypto.decrypt(
      key: masterKey,
      payload: EncryptedPayload.fromBase64(wrapped),
    );
    return SecretKey(base64Decode(noteKeyStr));
  }

  /// Wrap any key with another key (used for key history and PIN locks).
  Future<String> wrapKeyWith({
    required SecretKey wrappingKey,
    required SecretKey key,
    required String aad,
  }) async {
    return _crypto.seal(key: wrappingKey, data: await key.extractBytes(), aad: aad);
  }

  Future<SecretKey> unwrapKeyWith({
    required SecretKey wrappingKey,
    required String wrapped,
    required String aad,
  }) async {
    return SecretKey(
      await _crypto.open(key: wrappingKey, sealed: wrapped, aad: aad),
    );
  }

  // ------------------------------------------------------------------ sharing

  /// Encrypt a note key so only the owner of [recipientPublicKey] can unwrap it.
  Future<String> wrapNoteKeyForCollaborator({
    required SecretKey noteKey,
    required List<int> recipientPublicKey,
  }) async {
    final wrapKey = await _shareWrapKey(recipientPublicKey);
    final sealed = await _crypto.seal(
      key: wrapKey,
      data: await noteKey.extractBytes(),
      aad: 'notely-share-v2',
    );
    return '$_sharePrefixV2$sealed';
  }

  /// Decrypt a note key that was wrapped for us by the owner of [ownerPublicKey].
  Future<SecretKey> unwrapCollaboratorNoteKey({
    required String encryptedKeyStr,
    required List<int> ownerPublicKey,
  }) async {
    if (encryptedKeyStr.startsWith(_sharePrefixV2)) {
      final wrapKey = await _shareWrapKey(ownerPublicKey);
      final bytes = await _crypto.open(
        key: wrapKey,
        sealed: encryptedKeyStr.substring(_sharePrefixV2.length),
        aad: 'notely-share-v2',
      );
      return SecretKey(bytes);
    }
    // Legacy v1: raw ECDH output used directly as the AES key.
    final sharedSecret = await _ecdhSharedSecret(ownerPublicKey);
    final noteKeyStr = await _crypto.decrypt(
      key: sharedSecret,
      payload: EncryptedPayload.fromBase64(encryptedKeyStr),
    );
    return SecretKey(base64Decode(noteKeyStr));
  }

  Future<SimpleKeyPair> _loadMyKeyPair() async {
    if (_cachedKeyPair != null) return _cachedKeyPair!;
    final masterKey = await requireMasterKey();
    _cachedKeyPair =
        await _sharing.keyPairFromMasterKey(await masterKey.extractBytes());
    return _cachedKeyPair!;
  }

  Future<SecretKey> _ecdhSharedSecret(List<int> remotePublicKey) async {
    return _sharing.sharedSecret(
      myKeyPair: await _loadMyKeyPair(),
      remotePublicKey: remotePublicKey,
    );
  }

  /// HKDF over the ECDH output, bound to both public keys (order-independent)
  /// so the same pair of users always derives the same wrapping key.
  Future<SecretKey> _shareWrapKey(List<int> remotePublicKey) async {
    final shared = await _ecdhSharedSecret(remotePublicKey);
    final mine = await getMyPublicKey();
    final a = base64Encode(mine);
    final b = base64Encode(remotePublicKey);
    final transcript = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
    return _crypto.hkdf(
      secret: await shared.extractBytes(),
      salt: utf8.encode(transcript),
      info: 'notely-share-wrap-v2',
    );
  }

  /// This user's X25519 public key (32 bytes), derived deterministically
  /// from the master key, so it is identical on every device.
  Future<Uint8List> getMyPublicKey() async {
    final keyPair = await _loadMyKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }
}
