import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/lock/services/lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late LockAttemptStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1, 12);
    store = LockAttemptStore(clock: () => now);
  });

  test('first failures are free, then a cooldown starts', () async {
    expect(await store.recordFailure('n1'), Duration.zero);
    expect(await store.recordFailure('n1'), Duration.zero);
    expect(await store.recordFailure('n1'), const Duration(seconds: 30));
    expect(await store.remainingCooldown('n1'), const Duration(seconds: 30));
  });

  test('cooldown doubles on each further failure', () async {
    for (var i = 0; i < 3; i++) {
      await store.recordFailure('n1');
    }
    expect(await store.recordFailure('n1'), const Duration(seconds: 60));
    expect(await store.recordFailure('n1'), const Duration(seconds: 120));
  });

  test('cooldown survives a new store instance (app restart)', () async {
    for (var i = 0; i < 3; i++) {
      await store.recordFailure('n1');
    }
    final restarted = LockAttemptStore(clock: () => now.add(const Duration(seconds: 10)));
    expect(await restarted.remainingCooldown('n1'), const Duration(seconds: 20));
  });

  test('success clears failures; notes are tracked separately', () async {
    for (var i = 0; i < 3; i++) {
      await store.recordFailure('n1');
    }
    expect(await store.remainingCooldown('n2'), Duration.zero);
    await store.recordSuccess('n1');
    expect(await store.remainingCooldown('n1'), Duration.zero);
    expect(await store.recordFailure('n1'), Duration.zero);
  });
}
