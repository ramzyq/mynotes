import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/notely_typography.dart';

const notelyGlassTheme = GlassThemeData(
  light: GlassThemeVariant(
    settings: GlassThemeSettings(blur: 8, thickness: 30),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(
      primary: Color(0xFFA78BFA),
      glowBlurRadius: 10,
      glowOpacity: 0.6,
    ),
  ),
  dark: GlassThemeVariant(
    settings: GlassThemeSettings(blur: 10, thickness: 34),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(
      primary: Color(0xFFA78BFA),
      glowBlurRadius: 12,
      glowOpacity: 0.75,
    ),
  ),
);

ThemeData buildNotelyTheme(Brightness brightness) {
  final notely = brightness == Brightness.dark ? NotelyTheme.dark : NotelyTheme.light;

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: notely.bg,
    extensions: <ThemeExtension<dynamic>>[notely],
    colorScheme: ColorScheme.fromSeed(
      seedColor: notely.violet,
      brightness: brightness,
    ).copyWith(
      primary: notely.violet,
      onPrimary: Colors.white,
      surface: notely.surface,
      onSurface: notely.text,
      outline: notely.border,
    ),
    textTheme: buildNotelyTextTheme(brightness),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: notely.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    ),
    cardTheme: CardThemeData(
      color: notely.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: notely.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: notely.surface,
      hintStyle: TextStyle(color: notely.text3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: notely.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: notely.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: notely.violet, width: 1.4),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(elevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: notely.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: notely.surface,
      modalBackgroundColor: notely.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
