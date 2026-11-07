import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

/// Where the encrypted master-key backup lives. Abstracted for tests.
abstract class KeyBackupStore {
  Future<Map<String, dynamic>?> read(String uid);
  Future<void> write(String uid, Map<String, dynamic> data);
}

/// `users/{uid}/private/keyBackup` — owner-only per firestore.rules.
class FirestoreKeyBackupStore implements KeyBackupStore {
  FirestoreKeyBackupStore(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid).collection('private').doc('keyBackup');

  @override
  Future<Map<String, dynamic>?> read(String uid) async => (await _doc(uid).get()).data();

  @override
  Future<void> write(String uid, Map<String, dynamic> data) =>
      _doc(uid).set(data, SetOptions(merge: true));
}

sealed class KeySetupResult {
  const KeySetupResult();
}

/// The master key is loaded; the app can decrypt notes.
class KeySetupReady extends KeySetupResult {
  const KeySetupReady();
}

/// A new recovery code was created and must be shown to the user once.
class KeySetupShowRecoveryCode extends KeySetupResult {
  const KeySetupShowRecoveryCode(this.code);
  final String code;
}

/// A backup exists but this device can't open it without the recovery code
/// (e.g. Google sign-in on a new device, or the password was reset).
class KeySetupNeedsRecoveryCode extends KeySetupResult {
  const KeySetupNeedsRecoveryCode();
}

/// Backs the master key up so it survives reinstalls and new devices.
///
/// The backup document holds the master key encrypted under two independent
/// "slots": one keyed from the account password for seamless sign-in on new
/// devices, and one keyed from a random recovery code (HKDF) for Google
/// sign-in users and lost passwords. The password slot is opened with the
/// backup key from [PasswordSecretDeriver], which the sign-in server never
/// receives (it only gets the separate auth secret), so the server cannot
/// decrypt the backup.
class KeyBackupService {
  KeyBackupService({
    required this.keyManager,
    required this.store,
    CryptoService? crypto,
    this.publishedPublicKey,
  }) : _crypto = crypto ?? CryptoService();

  final KeyManager keyManager;
  final KeyBackupStore store;

  /// The base64 sharing public key on the user's profile, if any. Used to
  /// tell whether a legacy unscoped key on this device is this user's.
  final Future<String?> Function(String uid)? publishedPublicKey;
  final CryptoService _crypto;

  static const _formatVersion = 2;

  /// Make the master key available on this device for [uid]. [passwordKey]
  /// is the backup key derived at password sign-in (null for Google).
  Future<KeySetupResult> prepare({required String uid, List<int>? passwordKey}) async {
    keyManager.setActiveUser(uid);
    var local = await keyManager.loadMasterKey();
    final backup = await store.read(uid);
    final slots = _slots(backup);

    if (local == null) {
      final legacy = await keyManager.readLegacyMasterKey();
      if (legacy != null && await _legacyKeyBelongsTo(uid, legacy, hasBackup: slots.isNotEmpty)) {
        await keyManager.adoptLegacyMasterKey(legacy);
        local = await keyManager.loadMasterKey();
      }
    }

    if (local != null) {
      final masterBytes = await local.extractBytes();
      if (slots['recovery'] == null) {
        final code = generateRecoveryCode();
        await _writeSlots(uid, {
          'recovery': await _recoverySlot(uid, masterBytes, code),
          if (passwordKey != null) 'password': await _passwordSlot(uid, masterBytes, passwordKey),
        });
        return KeySetupShowRecoveryCode(code);
      }
      if (passwordKey != null && !await _passwordSlotOpens(uid, slots['password'], passwordKey, masterBytes)) {
        // Missing, or the password changed since it was written: re-wrap.
        await _writeSlots(uid, {'password': await _passwordSlot(uid, masterBytes, passwordKey)});
      }
      return const KeySetupReady();
    }

    if (backup != null && slots.isNotEmpty) {
      if (passwordKey != null && slots['password'] != null) {
        final bytes = await _tryOpenPasswordSlot(uid, slots['password']!, passwordKey);
        if (bytes != null) {
          await keyManager.storeMasterKey(bytes);
          return const KeySetupReady();
        }
      }
      return const KeySetupNeedsRecoveryCode();
    }

    // First ever setup for this account.
    final masterBytes = await keyManager.generateMasterKey();
    final code = generateRecoveryCode();
    await _writeSlots(uid, {
      'recovery': await _recoverySlot(uid, masterBytes, code),
      if (passwordKey != null) 'password': await _passwordSlot(uid, masterBytes, passwordKey),
    });
    return KeySetupShowRecoveryCode(code);
  }

  /// An older app version kept one unscoped key per device, so on a shared
  /// device it may be another account's. Adopt it only if it derives the
  /// public key on this user's profile or, for an account that never
  /// published one, if no backup exists (nothing else could hold its key).
  Future<bool> _legacyKeyBelongsTo(String uid, List<int> legacy, {required bool hasBackup}) async {
    final published = await publishedPublicKey?.call(uid);
    if (published == null) return !hasBackup;
    return base64Encode(await keyManager.publicKeyForMasterKey(legacy)) == published;
  }

  /// Restore the master key from the recovery code. Returns false if the
  /// code is wrong. Re-wraps the password slot when [passwordKey] is known.
  Future<bool> recoverWithCode({
    required String uid,
    required String code,
    List<int>? passwordKey,
  }) async {
    keyManager.setActiveUser(uid);
    final slot = _slots(await store.read(uid))['recovery'];
    if (slot == null) return false;
    try {
      final kek = await _recoveryKek(normalizeRecoveryCode(code), slot['salt'] as String);
      final bytes = await _crypto.open(
        key: kek,
        sealed: slot['wrapped'] as String,
        aad: _aad(uid, 'recovery'),
      );
      await keyManager.storeMasterKey(bytes);
      if (passwordKey != null) {
        await _writeSlots(uid, {'password': await _passwordSlot(uid, bytes, passwordKey)});
      }
      return true;
    } on SecretBoxAuthenticationError {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// Re-wrap the password slot for a new password (after a password change
  /// on a device that holds the master key). The recovery slot is untouched.
  Future<void> setPasswordSlot({required String uid, required List<int> passwordKey}) async {
    keyManager.setActiveUser(uid);
    final master = await keyManager.requireMasterKey();
    await _writeSlots(uid, {
      'password': await _passwordSlot(uid, await master.extractBytes(), passwordKey),
    });
  }

  /// Replace the recovery code (e.g. if the user lost the old one while
  /// still signed in). The old code stops working.
  Future<String> regenerateRecoveryCode(String uid) async {
    keyManager.setActiveUser(uid);
    final master = await keyManager.requireMasterKey();
    final code = generateRecoveryCode();
    await _writeSlots(uid, {
      'recovery': await _recoverySlot(uid, await master.extractBytes(), code),
    });
    return code;
  }

  // ------------------------------------------------------------ recovery code

  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford

  /// 128-bit random code, Crockford base32, grouped for readability.
  static String generateRecoveryCode() {
    final bytes = CryptoService.randomBytes(16);
    var bits = 0;
    var value = 0;
    final out = StringBuffer();
    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) out.write(_alphabet[(value << (5 - bits)) & 31]);
    final raw = out.toString();
    final groups = <String>[];
    for (var i = 0; i < raw.length; i += 4) {
      groups.add(raw.substring(i, i + 4 > raw.length ? raw.length : i + 4));
    }
    return groups.join('-');
  }

  /// Uppercase, drop separators/whitespace, and fold look-alike characters.
  static String normalizeRecoveryCode(String code) {
    return code
        .toUpperCase()
        .replaceAll(RegExp(r'[^0-9A-Z]'), '')
        .replaceAll('O', '0')
        .replaceAll(RegExp('[IL]'), '1')
        .replaceAll('U', 'V');
  }

  // ------------------------------------------------------------------- slots

  Map<String, Map<String, dynamic>> _slots(Map<String, dynamic>? backup) {
    final raw = backup?['slots'];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key as String: Map<String, dynamic>.from(entry.value as Map),
    };
  }

  Future<void> _writeSlots(String uid, Map<String, Map<String, dynamic>> slots) {
    return store.write(uid, {
      'version': _formatVersion,
      'slots': slots,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  String _aad(String uid, String slot) => 'notely-keybackup-v1:$uid:$slot';

  Future<SecretKey> _recoveryKek(String normalizedCode, String saltB64) {
    return _crypto.hkdf(
      secret: utf8.encode(normalizedCode),
      salt: base64Decode(saltB64),
      info: 'notely-recovery-v1',
    );
  }

  Future<Map<String, dynamic>> _recoverySlot(String uid, List<int> master, String code) async {
    final salt = base64Encode(_crypto.generateSalt());
    final kek = await _recoveryKek(normalizeRecoveryCode(code), salt);
    return {
      'kdf': 'hkdf-sha256',
      'salt': salt,
      'wrapped': await _crypto.seal(key: kek, data: master, aad: _aad(uid, 'recovery')),
    };
  }

  Future<Map<String, dynamic>> _passwordSlot(String uid, List<int> master, List<int> passwordKey) async {
    return {
      // The key is derived on the client (see PasswordSecretDeriver), so the
      // slot carries no salt or iteration count of its own.
      'kdf': 'notely-account-v1',
      'wrapped': await _crypto.seal(key: SecretKey(passwordKey), data: master, aad: _aad(uid, 'password')),
    };
  }

  Future<List<int>?> _tryOpenPasswordSlot(String uid, Map<String, dynamic> slot, List<int> passwordKey) async {
    try {
      return await _crypto.open(
        key: SecretKey(passwordKey),
        sealed: slot['wrapped'] as String,
        aad: _aad(uid, 'password'),
      );
    } on SecretBoxAuthenticationError {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<bool> _passwordSlotOpens(
    String uid,
    Map<String, dynamic>? slot,
    List<int> passwordKey,
    List<int> expected,
  ) async {
    if (slot == null) return false;
    final bytes = await _tryOpenPasswordSlot(uid, slot, passwordKey);
    if (bytes == null || bytes.length != expected.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != expected[i]) return false;
    }
    return true;
  }
}
