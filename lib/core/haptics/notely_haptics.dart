import 'dart:async';

import 'package:flutter/services.dart';

/// The app's small set of haptics, so every screen uses the same feel for
/// the same kind of moment. Each is one fire-and-forget platform call (no
/// timers), and does nothing where the device or the user's settings have no
/// haptics.
abstract final class NotelyHaptics {
  /// A field that changes the scene (the notes turning over, leaning in).
  static void select() => unawaited(HapticFeedback.selectionClick());

  /// Something small went right: a link sent, the passwords match.
  static void light() => unawaited(HapticFeedback.lightImpact());

  /// A deliberate action is under way, like creating the account.
  static void medium() => unawaited(HapticFeedback.mediumImpact());

  /// The sign-in or reset worked: felt as the logo's clip snaps on.
  static void success() => unawaited(HapticFeedback.mediumImpact());

  /// A wrong password: one firm knock with the card's shake.
  static void error() => unawaited(HapticFeedback.heavyImpact());
}
