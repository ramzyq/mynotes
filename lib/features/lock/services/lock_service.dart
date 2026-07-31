import 'package:cryptography/cryptography.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:math';
import 'dart:convert';

class LockService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const int _pinIterations = 10000;

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock this note',
      );
    } catch (_) {
      return false;
    }
  }

  Future<PinHash> hashPin(String pin) async {
    final salt = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pinIterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final keyBytes = await key.extractBytes();
    return PinHash(
      hash: base64Encode(keyBytes),
      salt: base64Encode(salt),
    );
  }

  Future<bool> verifyPin(String pin, PinHash stored) async {
    final salt = base64Decode(stored.salt);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pinIterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final keyBytes = await key.extractBytes();
    final computedHash = base64Encode(keyBytes);
    return computedHash == stored.hash;
  }
}

class PinHash {
  final String hash;
  final String salt;
  const PinHash({required this.hash, required this.salt});
}
