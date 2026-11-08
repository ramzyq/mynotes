import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why an email was sent, so each kind waits on its own.
enum ResendPurpose { verify, reset }

/// A wait between emails (verify, password reset), like most apps have:
/// it stops "send again" being tapped over and over while the first email is
/// still on its way. The send time is saved on the phone, so closing and
/// reopening the app keeps counting instead of starting over.
///
/// Firebase's own limit (too-many-requests) is still behind this.
class ResendCooldown {
  ResendCooldown({Future<SharedPreferences> Function()? prefs, DateTime Function()? now})
      : _prefs = prefs ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  static const length = Duration(seconds: 60);

  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;

  static String _key(ResendPurpose purpose, String email) => 'notely.resendAt.${purpose.name}.${email.trim().toLowerCase()}';

  /// An email of [purpose] just went to [email].
  Future<void> start(ResendPurpose purpose, String email) async {
    try {
      final prefs = await _prefs();
      await prefs.setInt(_key(purpose, email), _now().millisecondsSinceEpoch);
    } catch (error) {
      // Nowhere to save it: the wait only lasts while this screen is open.
      debugPrint('ResendCooldown.start: $error');
    }
  }

  /// How long until another email of [purpose] can go to [email].
  Future<Duration> remaining(ResendPurpose purpose, String email) async {
    try {
      final prefs = await _prefs();
      final at = prefs.getInt(_key(purpose, email));
      if (at == null) return Duration.zero;
      final left = length - _now().difference(DateTime.fromMillisecondsSinceEpoch(at));
      if (left <= Duration.zero) return Duration.zero;
      // A clock set backwards shouldn't mean a wait longer than the wait.
      return left > length ? length : left;
    } catch (error) {
      debugPrint('ResendCooldown.remaining: $error');
      return Duration.zero;
    }
  }
}

final resendCooldownProvider = Provider<ResendCooldown>((ref) => ResendCooldown());

/// Seconds left on a cooldown, ticking down once a second while a screen
/// shows it. Dispose with the screen.
class CooldownTicker extends ValueNotifier<int> {
  CooldownTicker() : super(0);

  Timer? _timer;

  void run(Duration left) {
    _timer?.cancel();
    value = left.inSeconds + (left.inMilliseconds % 1000 > 0 ? 1 : 0);
    if (value <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      value = value - 1;
      if (value <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// "0:42".
  static String format(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
