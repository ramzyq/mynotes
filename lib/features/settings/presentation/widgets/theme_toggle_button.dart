import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  final Color? foregroundColor;

  const ThemeToggleButton({super.key, this.foregroundColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final icon = isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    final label = isDark ? 'Light theme' : 'Dark theme';

    return IconButton(
      tooltip: label,
      onPressed: () {
        ref.read(themeModeProvider.notifier).set(isDark ? ThemeMode.light : ThemeMode.dark);
      },
      icon: Icon(icon, color: foregroundColor),
    );
  }
}
