import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/reminders/reminder_service.dart';

final reminderServiceProvider = Provider<ReminderService>((ref) => ReminderService());
