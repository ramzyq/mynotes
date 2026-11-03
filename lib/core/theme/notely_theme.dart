import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/notely_typography.dart';

// Screens that still use glass widgets get them without the colored glow.
const notelyGlassTheme = GlassThemeData(
  light: GlassThemeVariant(
    settings: GlassThemeSettings(blur: 8, thickness: 30),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(primary: Color(0xFF2F4AA0), glowBlurRadius: 0, glowOpacity: 0),
  ),
  dark: GlassThemeVariant(
    settings: GlassThemeSettings(blur: 10, thickness: 34),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(primary: Color(0xFF8FA6E8), glowBlurRadius: 0, glowOpacity: 0),
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
      onPrimary: brightness == Brightness.dark ? notely.bg : Colors.white,
      surface: notely.surface,
      onSurface: notely.text,
      outline: notely.border,
      error: notely.danger,
    ),
    textTheme: buildNotelyTextTheme(brightness),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: notely.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 16, fontWeight: FontWeight.w500, color: notely.text),
    ),
    cardTheme: CardThemeData(
      color: notely.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: notely.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: notely.surface,
      hintStyle: TextStyle(fontFamily: 'Geist', fontSize: 15, color: notely.text3),
      labelStyle: TextStyle(fontFamily: 'Geist', fontSize: 15, color: notely.text2),
      floatingLabelStyle: TextStyle(fontFamily: 'Geist', fontSize: 15, color: notely.violet),
      helperStyle: TextStyle(fontFamily: 'Geist', fontSize: 12, color: notely.text3),
      errorStyle: TextStyle(fontFamily: 'Geist', fontSize: 12, color: notely.danger),
      prefixIconColor: notely.text3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: notely.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: notely.danger, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: notely.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: notely.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: notely.violet, width: 1.5),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(elevation: 0),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: notely.violet,
        textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: notely.text,
        side: BorderSide(color: notely.borderStrong),
        textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    iconTheme: IconThemeData(color: notely.text2, size: 20),
    dividerTheme: DividerThemeData(color: notely.border, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: notely.text2,
      textColor: notely.text,
      titleTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 15, color: notely.text),
      subtitleTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : notely.text3),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? notely.violet : notely.surface2),
      trackOutlineColor: WidgetStatePropertyAll(notely.border),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: notely.violet, linearTrackColor: notely.surface2),
    popupMenuTheme: PopupMenuThemeData(
      color: notely.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: notely.border)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: notely.surface,
      selectedColor: notely.violetSoft2,
      side: BorderSide(color: notely.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text2),
      checkmarkColor: notely.violetInk,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: notely.text,
      contentTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.bg),
      actionTextColor: brightness == Brightness.dark ? notely.violetDeep : const Color(0xFFB9C8F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: notely.violet,
        foregroundColor: brightness == Brightness.dark ? notely.bg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: notely.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 18, fontWeight: FontWeight.w500, color: notely.text),
      contentTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 15, height: 1.5, color: notely.text2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: notely.surface,
      modalBackgroundColor: notely.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}
