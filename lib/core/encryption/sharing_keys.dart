import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class SharingKeys {
  static const String _seedDomain = 'mynotes-x25519-v1';
  final X25519 _x25519 = X25519();
  final Sha256 _sha256 = Sha256();

  Future<SimpleKeyPair> keyPairFromMasterKey(List<int> masterKeyBytes) async {
    final seedInput = [...utf8.encode(_seedDomain), ...masterKeyBytes];
    final seed = await _sha256.hash(seedInput);
    return _x25519.newKeyPairFromSeed(seed.bytes);
  }

  Future<List<int>> publicKeyOf(SimpleKeyPair pair) async {
    final publicKey = await pair.extractPublicKey();
    return publicKey.bytes;
  }

  Future<SecretKey> sharedSecret({
    required SimpleKeyPair myKeyPair,
    required List<int> remotePublicKey,
  }) {
    return _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: SimplePublicKey(
        remotePublicKey,
        type: KeyPairType.x25519,
      ),
    );
  }
}
