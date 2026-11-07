import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/core/error/error_handler.dart';

/// The new password is shorter than [PasswordSecretDeriver.minLength].
class PasswordTooShortException implements Exception {}

/// The password was changed, but the encrypted key backup still opens only
/// with the old one. Signing in again on this device repairs it; until then
/// a new device needs the recovery code.
class PasswordBackupNotUpdatedException implements Exception {}

/// Password reset and change for accounts whose password is split by
/// [PasswordSecretDeriver]. Every flow sends Firebase only auth secrets, so
/// they must all run in the app: Firebase's hosted reset page would store
/// the raw password, which then opens the key backup.
class PasswordAccountService {
  PasswordAccountService({required this.auth, required this.deriver, required this.keyBackup});

  final AuthProvider auth;
  final PasswordSecretDeriver deriver;
  final KeyBackupService keyBackup;

  static void _checkLength(String password) {
    if (password.length < PasswordSecretDeriver.minLength) throw PasswordTooShortException();
  }

  // ------------------------------------------------------------------ change

  /// Change the signed-in user's password and re-wrap the key backup for it.
  Future<void> changePassword({
    required AuthUser user,
    required String currentPassword,
    required String newPassword,
  }) async {
    _checkLength(newPassword);
    final current = await deriver.derive(email: user.email, password: currentPassword);
    final next = await deriver.derive(email: user.email, password: newPassword);
    await auth.changePassword(currentPassword: current.authSecret, newPassword: next.authSecret);
    try {
      await keyBackup.setPasswordSlot(uid: user.uid, passwordKey: next.backupKey);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      throw PasswordBackupNotUpdatedException();
    }
  }

  // ------------------------------------------------------------------- reset

  Future<void> sendResetEmail(String email) =>
      auth.sendPasswordResetEmail(PasswordSecretDeriver.normalizeEmail(email));

  /// The reset code in whatever the user pasted: the link from the reset
  /// email (also when wrapped in another link), or the bare code. Null when
  /// there is none, including for links meant for another action.
  static String? resetCodeFrom(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasQuery) {
      final params = uri.queryParameters;
      final mode = params['mode'];
      final code = params['oobCode'];
      if (code != null && code.isNotEmpty) return mode == null || mode == 'resetPassword' ? code : null;
      for (final key in const ['link', 'deep_link_id', 'continueUrl']) {
        final nested = params[key];
        final found = nested == null ? null : resetCodeFrom(nested);
        if (found != null) return found;
      }
      return null;
    }
    return RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(text) ? text : null;
  }

  /// Set a new password from a reset link. Returns the account email, so
  /// the sign-in screen can be filled in. The password slot of the key
  /// backup is re-wrapped on the next sign-in: on a device that still has
  /// the master key automatically, elsewhere after the recovery code.
  Future<String> completeReset({required String linkOrCode, required String newPassword}) async {
    final code = resetCodeFrom(linkOrCode);
    if (code == null) throw InvalidResetCodeAuthException();
    _checkLength(newPassword);
    final email = await auth.verifyPasswordResetCode(code);
    final secrets = await deriver.derive(email: email, password: newPassword);
    await auth.confirmPasswordReset(code: code, newPassword: secrets.authSecret);
    return email;
  }

  /// Repair an account whose password was set on Firebase's hosted reset
  /// page. Firebase has that password in plain text, so it can't protect
  /// the key backup: sign in with it once and replace it with [newPassword]
  /// (split as usual). [holdPasswordKey] receives the new backup key before
  /// sign-in, because signing in immediately starts the key setup.
  Future<void> repairWebReset({
    required String email,
    required String webPassword,
    required String newPassword,
    required void Function(List<int>? backupKey) holdPasswordKey,
  }) async {
    _checkLength(newPassword);
    final next = await deriver.derive(email: email, password: newPassword);
    holdPasswordKey(next.backupKey);
    try {
      await auth.logIn(email: email, password: webPassword);
    } catch (_) {
      holdPasswordKey(null);
      rethrow;
    }
    try {
      await auth.changePassword(currentPassword: webPassword, newPassword: next.authSecret);
    } catch (_) {
      // Don't leave the user signed in on the password Firebase knows.
      holdPasswordKey(null);
      await auth.logOut();
      rethrow;
    }
  }
}
