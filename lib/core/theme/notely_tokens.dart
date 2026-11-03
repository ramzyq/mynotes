import 'package:flutter/material.dart';

@immutable
class NotelyTheme extends ThemeExtension<NotelyTheme> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color text2;
  final Color text3;
  final Color text4;
  final Color violet;
  final Color violetDeep;
  final Color violetInk;
  final Color violetSoft;
  final Color violetSoft2;
  final Color success;
  final Color danger;

  const NotelyTheme({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.violet,
    required this.violetDeep,
    required this.violetInk,
    required this.violetSoft,
    required this.violetSoft2,
    required this.success,
    required this.danger,
  });

  // Paper and ink. Surfaces are a warm neutral ramp; the one accent is
  // fountain-pen ink. Field names keep "violet" for the accent so call sites
  // did not churn; read them as "ink".
  static const NotelyTheme light = NotelyTheme(
    bg: Color(0xFFF7F4EE),
    surface: Color(0xFFFDFBF7),
    surface2: Color(0xFFEFE9DF),
    border: Color(0x141F1B16),
    borderStrong: Color(0x241F1B16),
    text: Color(0xFF1F1B16),
    text2: Color(0xFF5E554A),
    text3: Color(0xFF7B7266),
    text4: Color(0xFF9A9184),
    violet: Color(0xFF2F4AA0),
    violetDeep: Color(0xFF263C85),
    violetInk: Color(0xFF22357A),
    violetSoft: Color(0x142F4AA0),
    violetSoft2: Color(0x242F4AA0),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
  );

  static const NotelyTheme dark = NotelyTheme(
    bg: Color(0xFF161513),
    surface: Color(0xFF1C1A18),
    surface2: Color(0xFF262421),
    border: Color(0x14EFE9DE),
    borderStrong: Color(0x24EFE9DE),
    text: Color(0xFFEFE9DE),
    text2: Color(0xFFAAA398),
    text3: Color(0xFF8A847A),
    text4: Color(0xFF6E685F),
    violet: Color(0xFF8FA6E8),
    violetDeep: Color(0xFF6F88D6),
    violetInk: Color(0xFFB9C8F2),
    violetSoft: Color(0x1A8FA6E8),
    violetSoft2: Color(0x2B8FA6E8),
    success: Color(0xFF4CC38A),
    danger: Color(0xFFE5484D),
  );

  static NotelyTheme of(BuildContext context) {
    final t = Theme.of(context).extension<NotelyTheme>();
    assert(t != null, 'NotelyTheme not present in ThemeData');
    return t!;
  }

  static const _displaySerif = TextStyle(
    fontFamily: 'Instrument Serif',
    fontFamilyFallback: ['Geist'],
    fontStyle: FontStyle.italic,
  );

  TextStyle get displaySerif => _displaySerif;

  TextStyle get bodyGeist => const TextStyle(fontFamily: 'Geist');

  @override
  NotelyTheme copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? text2,
    Color? text3,
    Color? text4,
    Color? violet,
    Color? violetDeep,
    Color? violetInk,
    Color? violetSoft,
    Color? violetSoft2,
    Color? success,
    Color? danger,
  }) {
    return NotelyTheme(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      text4: text4 ?? this.text4,
      violet: violet ?? this.violet,
      violetDeep: violetDeep ?? this.violetDeep,
      violetInk: violetInk ?? this.violetInk,
      violetSoft: violetSoft ?? this.violetSoft,
      violetSoft2: violetSoft2 ?? this.violetSoft2,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  NotelyTheme lerp(ThemeExtension<NotelyTheme>? other, double t) {
    if (other is! NotelyTheme) return this;
    return NotelyTheme(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      text4: Color.lerp(text4, other.text4, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      violetDeep: Color.lerp(violetDeep, other.violetDeep, t)!,
      violetInk: Color.lerp(violetInk, other.violetInk, t)!,
      violetSoft: Color.lerp(violetSoft, other.violetSoft, t)!,
      violetSoft2: Color.lerp(violetSoft2, other.violetSoft2, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
