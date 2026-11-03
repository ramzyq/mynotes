import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class NotelyAvatar extends StatelessWidget {
  final double size;
  final String initial;
  final bool ring;

  const NotelyAvatar({super.key, this.size = 32, required this.initial, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final char = initial.isNotEmpty ? initial.substring(0, 1).toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: notely.surface2,
        border: Border.all(color: ring ? notely.borderStrong : notely.border),
      ),
      child: Text(char, style: TextStyle(fontFamily: 'Geist', color: notely.text2, fontWeight: FontWeight.w500, fontSize: size * 0.42)),
    );
  }
}
