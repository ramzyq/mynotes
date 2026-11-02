import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager(crypto: ref.watch(cryptoServiceProvider));
});

final keyBackupServiceProvider = Provider<KeyBackupService>((ref) {
  return KeyBackupService(
    keyManager: ref.watch(keyManagerProvider),
    store: FirestoreKeyBackupStore(FirebaseFirestore.instance),
    crypto: ref.watch(cryptoServiceProvider),
  );
});

/// The password typed at sign-in/registration, held in memory only until the
/// key setup gate has used it to open or create the key backup.
final pendingPasswordProvider = StateProvider<String?>((ref) => null);
