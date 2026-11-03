import 'package:flutter/material.dart';

/// One scale for the app: 12 meta, 13 captions, 15 body, 16 titles,
/// 32/40 serif display. Weights 400 and 500; 600 only for the wordmark.
/// No negative tracking below display sizes.
TextTheme buildNotelyTextTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? const Color(0xFFEFE9DE) : const Color(0xFF1F1B16);
  final secondary = dark ? const Color(0xFFAAA398) : const Color(0xFF5E554A);
  final muted = dark ? const Color(0xFF8A847A) : const Color(0xFF7B7266);

  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Instrument Serif',
      fontSize: 40,
      height: 1.05,
      letterSpacing: -0.8,
      color: primary,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Instrument Serif',
      fontSize: 32,
      height: 1.1,
      letterSpacing: -0.5,
      color: primary,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Geist',
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Geist',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Geist',
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Geist',
      fontSize: 16,
      height: 1.6,
      color: primary,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Geist',
      fontSize: 15,
      height: 1.5,
      color: primary,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Geist',
      fontSize: 13,
      height: 1.45,
      color: secondary,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Geist',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Geist',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    labelSmall: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 12,
      color: muted,
    ),
  );
}
