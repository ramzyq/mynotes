import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/lock/services/lock_service.dart';

void main() {
  late LockService lockService;

  setUp(() {
    lockService = LockService();
  });

  test('hashPin produces consistent results', () async {
    const pin = '123456';
    final hash1 = await lockService.hashPin(pin);
    final hash2 = await lockService.hashPin(pin);

    expect(hash1.hash, isNot(equals(hash2.hash)));
  });

  test('verifyPin succeeds with correct pin', () async {
    const pin = '654321';
    final stored = await lockService.hashPin(pin);
    final valid = await lockService.verifyPin(pin, stored);
    expect(valid, isTrue);
  });

  test('verifyPin fails with wrong pin', () async {
    const correct = '123456';
    const wrong = '654321';
    final stored = await lockService.hashPin(correct);
    final valid = await lockService.verifyPin(wrong, stored);
    expect(valid, isFalse);
  });
}
