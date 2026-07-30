import 'package:flutter/material.dart';

class AppThemeScope extends InheritedWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const AppThemeScope({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
    required super.child,
  });

  static AppThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) {
    return isDarkMode != oldWidget.isDarkMode;
  }
}

class ThemeToggleButton extends StatelessWidget {
  final Color? foregroundColor;

  const ThemeToggleButton({super.key, this.foregroundColor});

  @override
  Widget build(BuildContext context) {
    final scope = AppThemeScope.of(context);
    final icon = scope.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    final label = scope.isDarkMode ? 'Light theme' : 'Dark theme';

    return IconButton(
      tooltip: label,
      onPressed: scope.toggleTheme,
      icon: Icon(icon, color: foregroundColor),
    );
  }
}
