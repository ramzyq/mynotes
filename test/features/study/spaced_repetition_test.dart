import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/study/services/spaced_repetition.dart';

void main() {
  test('first two good reviews give 1 and 6 day intervals', () {
    final first = calculateSM2(quality: 4, easeFactor: 2.5, repetitions: 0, interval: 0);
    expect(first.repetitions, 1);
    expect(first.interval, 1);

    final second = calculateSM2(
        quality: 4, easeFactor: first.easeFactor, repetitions: first.repetitions, interval: first.interval);
    expect(second.repetitions, 2);
    expect(second.interval, 6);
  });

  test('later reviews multiply the interval by the ease factor', () {
    final result = calculateSM2(quality: 5, easeFactor: 2.5, repetitions: 2, interval: 6);
    expect(result.repetitions, 3);
    expect(result.easeFactor, closeTo(2.6, 1e-9));
    expect(result.interval, (6 * 2.6).round());
  });

  test('a failed review resets progress', () {
    final result = calculateSM2(quality: 2, easeFactor: 2.5, repetitions: 5, interval: 40);
    expect(result.repetitions, 0);
    expect(result.interval, 1);
  });

  test('ease factor never drops below 1.3', () {
    final result = calculateSM2(quality: 0, easeFactor: 1.3, repetitions: 0, interval: 1);
    expect(result.easeFactor, 1.3);
  });

  test('due date is interval days from now', () {
    final before = DateTime.now();
    final result = calculateSM2(quality: 4, easeFactor: 2.5, repetitions: 1, interval: 1);
    expect(result.dueAt.difference(before).inDays, result.interval);
  });
}
