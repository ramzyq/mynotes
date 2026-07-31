class SM2Result {
  final int interval;
  final double easeFactor;
  final int repetitions;
  final DateTime dueAt;

  SM2Result({
    required this.interval,
    required this.easeFactor,
    required this.repetitions,
    required this.dueAt,
  });
}

SM2Result calculateSM2({
  required int quality,
  required double easeFactor,
  required int repetitions,
  required int interval,
}) {
  double newEaseFactor =
      easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (newEaseFactor < 1.3) newEaseFactor = 1.3;

  int newRepetitions;
  int newInterval;

  if (quality < 3) {
    newRepetitions = 0;
    newInterval = 1;
  } else {
    newRepetitions = repetitions + 1;
    if (newRepetitions == 1) {
      newInterval = 1;
    } else if (newRepetitions == 2) {
      newInterval = 6;
    } else {
      newInterval = (interval * newEaseFactor).round();
    }
  }

  return SM2Result(
    interval: newInterval,
    easeFactor: newEaseFactor,
    repetitions: newRepetitions,
    dueAt: DateTime.now().add(Duration(days: newInterval)),
  );
}
