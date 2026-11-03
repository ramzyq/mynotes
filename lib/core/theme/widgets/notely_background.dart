import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

/// The page: plain paper. Content carries the color, not the backdrop.
class NotelyBackground extends StatelessWidget {
  const NotelyBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: NotelyTheme.of(context).bg, child: const SizedBox.expand());
  }
}
