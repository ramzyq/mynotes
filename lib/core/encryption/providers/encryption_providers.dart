import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager();
});

final hasMasterKeyProvider = FutureProvider<bool>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  return keyManager.hasMasterKey();
});
