import 'dart:convert';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// The two secrets an account password is split into.
class PasswordSecrets {
  const PasswordSecrets({required this.authSecret, required this.backupKey});

  /// Sent to Firebase Auth in place of the password.
  final String authSecret;

  /// Opens the password slot of the key backup. Never leaves the device.
  final List<int> backupKey;
}

/// Splits an account password so that the sign-in server never receives
/// anything that can open the user's notes.
///
///   stretched  = PBKDF2-SHA256(NFC(password), 600k, salt: "notely-account-v1:" + email)
///   authSecret = HKDF(stretched, info: "notely-auth-v1")          -> Firebase
///   backupKey  = HKDF(stretched, info: "notely-password-slot-v1") -> device only
///
/// HKDF outputs with different `info` are independent, so knowing the auth
/// secret reveals nothing about the backup key. Firebase can still try to
/// guess the password offline from the auth secret; each guess costs the
/// full PBKDF2 work, and that is the remaining risk a strong password
/// covers. The salt is the normalized email because it must be known before
/// sign-in, when nothing else about the account is.
///
/// The password is NFC-normalized first (as RFC 8265's OpaqueString does),
/// so the same password typed on keyboards that compose accented letters
/// differently derives the same secrets.
///
/// The parameters are fixed per [kdfVersion]: they have to be known before
/// sign-in, so they can't be read from the account. To strengthen them
/// later, add a version, try the newest at sign-in and fall back to older
/// ones, then upgrade the account with a password change.
///
/// Consequences for any future account feature:
/// - Password reset and change must run in the app (`confirmPasswordReset`
///   / `updatePassword` with a new auth secret, then re-wrap the password
///   slot). Firebase's hosted reset page would store the raw password.
/// - Changing the account email changes the salt, so it must re-derive and
///   update both secrets at the same time.
class PasswordSecretDeriver {
  PasswordSecretDeriver({CryptoService? crypto, this.iterations = defaultIterations})
      : _crypto = crypto ?? CryptoService();

  final CryptoService _crypto;
  final int iterations;

  /// OWASP's current recommendation for PBKDF2-HMAC-SHA256. Runs natively
  /// (cryptography_flutter), so it costs well under a second on most phones.
  static const defaultIterations = 600000;

  /// Recorded on the key backup's password slot, which refuses others.
  static const kdfVersion = 'notely-account-v1';

  /// The server can no longer enforce a password policy (it never sees the
  /// password), and the password is now what guards against offline
  /// guessing, so the app enforces this minimum itself.
  static const minLength = 8;

  /// Fixed prefix so the auth secret satisfies any Firebase password policy
  /// (upper, lower, digit, symbol) whatever the base64 part contains.
  static const _policyPrefix = 'Nt1!';

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<PasswordSecrets> derive({required String email, required String password}) async {
    final stretched = await _crypto.deriveKey(
      password: unorm.nfc(password),
      salt: utf8.encode('$kdfVersion:${normalizeEmail(email)}'),
      iterations: iterations,
    );
    final stretchedBytes = await stretched.extractBytes();
    final auth = await _crypto.hkdf(secret: stretchedBytes, info: 'notely-auth-v1');
    final backup = await _crypto.hkdf(secret: stretchedBytes, info: 'notely-password-slot-v1');
    return PasswordSecrets(
      authSecret: '$_policyPrefix${base64UrlEncode(await auth.extractBytes())}',
      backupKey: await backup.extractBytes(),
    );
  }
}
