import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';

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
    publishedPublicKey: (uid) async {
      final profile = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return profile.data()?['publicKey'] as String?;
    },
  );
});

final passwordSecretDeriverProvider = Provider<PasswordSecretDeriver>((ref) {
  return PasswordSecretDeriver(crypto: ref.watch(cryptoServiceProvider));
});

/// The backup key derived from the password at sign-in/registration (see
/// PasswordSecretDeriver), held in memory only until the key setup gate has
/// used it to open or create the key backup. The password itself is not kept.
final pendingPasswordKeyProvider = StateProvider<List<int>?>((ref) => null);
