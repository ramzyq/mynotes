import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric prompt wrapper. PIN handling lives in NotesService because a
/// PIN lock is cryptographic (the PIN unwraps the note key).
class LockService {
  final LocalAuthentication _localAuth = LocalAuthentication();

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
}

/// Failed-PIN bookkeeping persisted on the device, so closing and reopening
/// the lock screen (or restarting the app) does not reset the cooldown.
/// After [freeAttempts] failures each further failure doubles the wait,
/// starting at 30 seconds and capped at one hour.
class LockAttemptStore {
  LockAttemptStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  static const freeAttempts = 3;
  static const _baseCooldown = Duration(seconds: 30);
  static const _maxCooldown = Duration(hours: 1);

  String _countKey(String noteId) => 'lock_failures_$noteId';
  String _untilKey(String noteId) => 'lock_until_$noteId';

  /// Time remaining before another attempt is allowed (zero if allowed now).
  Future<Duration> remainingCooldown(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_untilKey(noteId));
    if (until == null) return Duration.zero;
    final remaining = DateTime.fromMillisecondsSinceEpoch(until).difference(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Record a failure and return the new cooldown (zero if none applies).
  Future<Duration> recordFailure(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final failures = (prefs.getInt(_countKey(noteId)) ?? 0) + 1;
    await prefs.setInt(_countKey(noteId), failures);
    if (failures < freeAttempts) return Duration.zero;

    final exponent = failures - freeAttempts;
    var cooldown = _baseCooldown * (1 << (exponent > 7 ? 7 : exponent));
    if (cooldown > _maxCooldown) cooldown = _maxCooldown;
    await prefs.setInt(_untilKey(noteId), _clock().add(cooldown).millisecondsSinceEpoch);
    return cooldown;
  }

  Future<void> recordSuccess(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey(noteId));
    await prefs.remove(_untilKey(noteId));
  }
}
