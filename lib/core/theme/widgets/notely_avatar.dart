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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC4A7FF), Color(0xFF8B5CF6), Color(0xFF5B21B6)],
          stops: [0, 0.55, 1],
        ),
        boxShadow: ring
            ? [BoxShadow(color: notely.surface, spreadRadius: 2), BoxShadow(color: notely.violet, spreadRadius: 3.5)]
            : const [BoxShadow(color: Color(0x403C1E78), blurRadius: 1, offset: Offset(0, 1))],
      ),
      child: Text(char, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.42, letterSpacing: -0.2)),
    );
  }
}
