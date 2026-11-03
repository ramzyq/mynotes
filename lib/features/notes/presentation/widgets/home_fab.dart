import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

/// The one primary action on the home screen. Ink fill, no glow.
class HomeFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const HomeFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: dark ? null : const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(200, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: notely.violet,
              foregroundColor: dark ? notely.bg : Colors.white,
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Start writing'),
          ),
        ),
      ),
    );
  }
}
