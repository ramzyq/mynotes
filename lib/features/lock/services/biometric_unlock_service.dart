import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device storage whose items can only be read after a biometric check.
abstract class BiometricKeyStore {
  Future<void> write(String name, String value);

  /// Returns null if the item is missing or was invalidated (e.g. a new
  /// fingerprint was enrolled). Throws if the user cancelled or auth failed.
  Future<String?> read(String name);
  Future<void> delete(String name);
}

/// Android Keystore (strong biometrics, invalidated on enrollment change)
/// and iOS Keychain (`biometryCurrentSet`, this device only).
///
/// Uses its own storage namespace / keychain service so that a reset of this
/// store (which Android performs when the biometric key is invalidated) can
/// never touch the master key kept in the default secure storage.
class SecureBiometricKeyStore implements BiometricKeyStore {
  SecureBiometricKeyStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions.biometric(
            enforceBiometrics: true,
            biometricType: AndroidBiometricType.strongBiometricOnly,
            storageNamespace: 'notely_biometric',
            biometricPromptTitle: 'Unlock note',
            biometricPromptSubtitle: 'Confirm it is you to open this locked note',
            biometricPromptNegativeButton: 'Use PIN',
          ),
          iOptions: IOSOptions(
            accountName: 'notely_biometric',
            accessibility: KeychainAccessibility.passcode,
            synchronizable: false,
            accessControlFlags: [AccessControlFlag.biometryCurrentSet],
          ),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String name, String value) => _storage.write(key: name, value: value);

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}

/// The platform biometric prompt and capability checks.
abstract class BiometricPrompter {
  /// Whether biometric unlock can be offered with hardware-enforced storage.
  Future<bool> isSupported();
  Future<bool> authenticate(String reason);
}

class DeviceBiometricPrompter implements BiometricPrompter {
  final LocalAuthentication _auth = LocalAuthentication();
  static const _device = MethodChannel('notely/device');

  @override
  Future<bool> isSupported() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return false;
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) return false;
      final available = await _auth.getAvailableBiometrics();
      if (Platform.isAndroid) {
        // Below API 28 the Keystore item would silently not require
        // biometrics, and only Class 3 ("strong") biometrics can unlock
        // Keystore keys.
        final sdk = await _device.invokeMethod<int>('androidSdkInt') ?? 0;
        return sdk >= 28 && available.contains(BiometricType.strong);
      }
      return available.isNotEmpty;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}

sealed class BiometricUnlockResult {
  const BiometricUnlockResult();
}

class BiometricUnlocked extends BiometricUnlockResult {
  const BiometricUnlocked(this.note);
  final Note note;
}

/// The user cancelled or the check failed; the PIN still works.
class BiometricCancelled extends BiometricUnlockResult {
  const BiometricCancelled();
}

/// Biometric unlock no longer works for this note on this device (new
/// fingerprint enrolled, PIN changed, ...). It has been turned off.
class BiometricNoLongerAvailable extends BiometricUnlockResult {
  const BiometricNoLongerAvailable();
}

/// Lets a PIN-locked note be opened with Face ID / Touch ID / fingerprint.
///
/// The PIN-derived key of the note is stored in biometric-protected device
/// storage. Biometrics never replace the PIN: the PIN keeps working, and on a
/// new device (or after biometric enrollment changes) only the PIN does.
class BiometricUnlockService {
  BiometricUnlockService({
    required this.notesService,
    BiometricKeyStore? store,
    BiometricPrompter? prompter,
    bool? isAndroid,
  })  : _store = store ?? SecureBiometricKeyStore(),
        _prompter = prompter ?? DeviceBiometricPrompter(),
        _isAndroid = isAndroid ?? Platform.isAndroid;

  final NotesService notesService;
  final BiometricKeyStore _store;
  final BiometricPrompter _prompter;
  final bool _isAndroid;

  /// Android authenticates once to open the Keystore-backed store and then
  /// keeps it open for the rest of the process. After that first unlock we
  /// show our own biometric prompt, so every note still needs a fresh check.
  bool _androidStoreOpened = false;

  String _itemName(String uid, String noteId) => 'pin_kek_${uid}_$noteId';
  String _indexKey(String uid) => 'biometric_unlock_$uid';

  Future<bool> isSupported() => _prompter.isSupported();

  Future<Set<String>> _index(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_indexKey(uid)) ?? const []).toSet();
  }

  Future<void> _saveIndex(String uid, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_indexKey(uid), ids.toList()..sort());
  }

  Future<bool> isEnabled(String uid, String noteId) async => (await _index(uid)).contains(noteId);

  /// Turn on biometric unlock for a note that is currently unlocked with its
  /// PIN. Shows the biometric prompt. Returns false if it could not be set up.
  Future<bool> enable(String uid, String noteId) async {
    final kek = await notesService.exportPinKek(noteId);
    if (kek == null) return false;
    try {
      await _store.write(_itemName(uid, noteId), base64Encode(kek));
      _androidStoreOpened = true;
      await _saveIndex(uid, {...await _index(uid), noteId});
      return true;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      return false;
    }
  }

  Future<void> disable(String uid, String noteId) async {
    try {
      await _store.delete(_itemName(uid, noteId));
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
    }
    await _saveIndex(uid, (await _index(uid))..remove(noteId));
  }

  Future<BiometricUnlockResult> unlock(String uid, Note note) async {
    if (!await isEnabled(uid, note.id)) return const BiometricNoLongerAvailable();

    if (_isAndroid && _androidStoreOpened) {
      if (!await _prompter.authenticate('Unlock this note')) return const BiometricCancelled();
    }

    final String? stored;
    try {
      stored = await _store.read(_itemName(uid, note.id));
      _androidStoreOpened = true;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      return const BiometricCancelled();
    }

    if (stored == null) {
      await disable(uid, note.id);
      return const BiometricNoLongerAvailable();
    }

    final unlocked = await notesService.unlockWithKek(note: note, kek: base64Decode(stored));
    if (unlocked == null) {
      await disable(uid, note.id);
      return const BiometricNoLongerAvailable();
    }
    return BiometricUnlocked(unlocked);
  }

  /// Drop entries for notes that were deleted or are no longer PIN-locked.
  Future<void> prune(String uid, Iterable<Note> notes) async {
    final index = await _index(uid);
    if (index.isEmpty) return;
    final stillLocked = {for (final n in notes) if (n.pinWrappedKey != null) n.id};
    for (final noteId in index.difference(stillLocked)) {
      await disable(uid, noteId);
    }
  }
}
