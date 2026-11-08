import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/auth/services/resend_cooldown.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  ResendCooldown cooldown() => ResendCooldown(now: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 8, 12);
  });

  test('nothing sent yet: no wait', () async {
    expect(await cooldown().remaining(ResendPurpose.verify, 'maya@example.com'), Duration.zero);
  });

  test('counts down from a minute, and survives a restart', () async {
    await cooldown().start(ResendPurpose.verify, 'Maya@Example.com');
    now = now.add(const Duration(seconds: 20));
    // A fresh instance, as after reopening the app; email case doesn't matter.
    expect(await cooldown().remaining(ResendPurpose.verify, 'maya@example.com'), const Duration(seconds: 40));
    now = now.add(const Duration(seconds: 40));
    expect(await cooldown().remaining(ResendPurpose.verify, 'maya@example.com'), Duration.zero);
  });

  test('each kind of email waits on its own', () async {
    await cooldown().start(ResendPurpose.reset, 'maya@example.com');
    expect(await cooldown().remaining(ResendPurpose.verify, 'maya@example.com'), Duration.zero);
    expect(await cooldown().remaining(ResendPurpose.reset, 'sam@example.com'), Duration.zero);
  });

  test('a clock set backwards never means more than a minute', () async {
    await cooldown().start(ResendPurpose.verify, 'maya@example.com');
    now = now.subtract(const Duration(hours: 1));
    expect(await cooldown().remaining(ResendPurpose.verify, 'maya@example.com'), ResendCooldown.length);
  });

  test('formats as m:ss', () {
    expect(CooldownTicker.format(60), '1:00');
    expect(CooldownTicker.format(9), '0:09');
  });
}
