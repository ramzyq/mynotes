import 'package:flutter/material.dart';

TextTheme buildNotelyTextTheme(Brightness brightness) {
  final displayColor = brightness == Brightness.dark ? const Color(0xFFF5F2FB) : const Color(0xFF1B1427);
  final bodyColor = brightness == Brightness.dark ? const Color(0xFFF5F2FB) : const Color(0xFF1B1427);

  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Instrument Serif',
      fontSize: 42,
      height: 1.02,
      letterSpacing: -1.2,
      color: displayColor,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Instrument Serif',
      fontSize: 30,
      height: 1.1,
      letterSpacing: -0.6,
      color: displayColor,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Geist',
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: bodyColor,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Geist',
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: bodyColor,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Geist',
      fontSize: 15,
      height: 1.5,
      color: bodyColor,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Geist',
      fontSize: 13,
      color: brightness == Brightness.dark ? const Color(0xFFB8B0C2) : const Color(0xFF5A5166),
    ),
    labelMedium: TextStyle(
      fontFamily: 'Geist',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: bodyColor,
    ),
    labelSmall: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 11,
      color: brightness == Brightness.dark ? const Color(0xFF8A8394) : const Color(0xFF7A7186),
    ),
  );
}
