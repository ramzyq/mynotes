import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:quick_actions/quick_actions.dart';

/// Ways to start a note from outside the app:
/// - a "New note" shortcut on the app icon (Android and iOS), and
/// - "Share > Notely" for text from other apps (Android; see MainActivity).
///
/// Shared text goes straight into a new note on this device, where it is
/// encrypted on save like anything else you type.
class QuickCaptureService {
  QuickCaptureService({QuickActions? quickActions, MethodChannel? channel})
      : _quickActions = quickActions ?? const QuickActions(),
        _channel = channel ?? const MethodChannel('notely/share');

  final QuickActions _quickActions;
  final MethodChannel _channel;

  static const newNoteShortcut = 'new_note';

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// [onNewNote] is called with the shared text, or null for an empty note.
  Future<void> start(void Function(String? text) onNewNote) async {
    if (!_mobile) return;
    try {
      await _quickActions.initialize((type) {
        if (type == newNoteShortcut) onNewNote(null);
      });
      await _quickActions.setShortcutItems(const [
        ShortcutItem(type: newNoteShortcut, localizedTitle: 'New note', icon: 'ic_launcher'),
      ]);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
    }

    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedTextAvailable') {
        final text = await takeSharedText();
        if (text != null) onNewNote(text);
      }
    });
    final launchText = await takeSharedText();
    if (launchText != null) onNewNote(launchText);
  }

  /// Text shared into the app that has not been used yet, if any.
  Future<String?> takeSharedText() async {
    if (!_mobile || !Platform.isAndroid) return null;
    try {
      final text = await _channel.invokeMethod<String>('takeSharedText');
      return text == null || text.trim().isEmpty ? null : text;
    } on MissingPluginException {
      return null;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      return null;
    }
  }

  void stop() {
    if (_mobile && Platform.isAndroid) _channel.setMethodCallHandler(null);
  }
}
