/// One date style for the whole app: "Nov 3, 14:05", with the year only
/// when it is not this year. Times are 24-hour, like the rest of the app.
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDay(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = '${_months[date.month - 1]} ${date.day}';
  return date.year == today.year ? day : '$day, ${date.year}';
}

String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatDateTime(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = d.difference(t).inDays;
  final day = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => formatDay(date, now: today),
  };
  return '$day, ${formatTime(date)}';
}
