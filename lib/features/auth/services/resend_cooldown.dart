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

/// Seconds left on a cooldown, updated while a screen shows it. Counts
/// against the clock, not ticks, so time spent in the background (when
/// timers can pause) still counts. Dispose with the screen.
class CooldownTicker extends ValueNotifier<int> {
  CooldownTicker({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(0);

  final DateTime Function() _now;
  Timer? _timer;
  DateTime? _endsAt;

  void run(Duration left) {
    _timer?.cancel();
    _endsAt = _now().add(left);
    _update();
    if (value <= 0) return;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _update());
  }

  void _update() {
    final ms = _endsAt!.difference(_now()).inMilliseconds;
    value = ms <= 0 ? 0 : (ms + 999) ~/ 1000;
    if (value <= 0) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// "0:42".
  static String format(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
