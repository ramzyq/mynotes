import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules note reminders as local notifications on this device.
///
/// Reminder times live in each note's encrypted metadata, so every signed-in
/// device learns about them when notes sync, and [sync] makes the scheduled
/// notifications on this device match. Nothing about reminders is sent to a
/// server. Notifications show the note title unless the note is locked.
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Notification ids currently scheduled by [sync], by note id.
  final Map<String, ({int id, DateTime at, String title})> _scheduled = {};

  static const _channel = AndroidNotificationDetails(
    'note_reminders',
    'Note reminders',
    channelDescription: 'Reminders you set on your notes',
    importance: Importance.high,
    priority: Priority.high,
  );

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// Stable notification id for a note.
  static int idFor(String noteId) {
    var hash = 7;
    for (final unit in noteId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  /// [onOpen] receives the note id when a reminder notification is tapped.
  Future<void> init({void Function(String noteId)? onOpen}) async {
    if (_initialized || !_supported) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final noteId = response.payload;
          if (noteId != null && noteId.isNotEmpty) onOpen?.call(noteId);
        },
      );
      _initialized = true;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
    }
  }

  /// The note id of the reminder that launched the app, if any.
  Future<String?> launchNoteId() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details!.notificationResponse?.payload;
    return payload == null || payload.isEmpty ? null : payload;
  }

  /// Ask for permission to show notifications. Call when the user sets a
  /// reminder, not at launch. Returns false if refused.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();
    try {
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      return false;
    }
  }

  /// Make scheduled notifications match the reminders on [notes]: schedule
  /// new or changed ones and cancel those removed, past, trashed or deleted.
  Future<void> sync(Iterable<Note> notes, {DateTime? now}) async {
    if (!_initialized) return;
    final at = now ?? DateTime.now();
    final wanted = <String, ({int id, DateTime at, String title})>{
      for (final note in notes)
        if (note.reminderAt != null && note.reminderAt!.isAfter(at) && !note.isTrashed && !note.isExpired)
          note.id: (
            id: idFor(note.id),
            at: note.reminderAt!,
            title: note.isLocked ? 'Locked note' : note.displayTitle,
          ),
    };
    try {
      for (final entry in _scheduled.entries.toList()) {
        if (wanted[entry.key] != entry.value) {
          await _plugin.cancel(entry.value.id);
          _scheduled.remove(entry.key);
        }
      }
      for (final entry in wanted.entries) {
        if (_scheduled[entry.key] == entry.value) continue;
        await _plugin.zonedSchedule(
          entry.value.id,
          entry.value.title,
          'Reminder from Notely',
          tz.TZDateTime.from(entry.value.at.toUtc(), tz.UTC),
          const NotificationDetails(
            android: _channel,
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: entry.key,
        );
        _scheduled[entry.key] = entry.value;
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
    }
  }

  /// Cancel everything, for example on sign-out.
  Future<void> cancelAll() async {
    _scheduled.clear();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
    }
  }
}
