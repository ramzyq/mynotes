import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'notely.themeMode';

/// The saved theme, or system if none (or if it can't be read).
Future<ThemeMode> readSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_prefsKey));
  } catch (_) {
    return ThemeMode.system;
  }
}

ThemeMode _parse(String? value) => switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeModeNotifier();

  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = _parse(prefs.getString(_prefsKey));
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
