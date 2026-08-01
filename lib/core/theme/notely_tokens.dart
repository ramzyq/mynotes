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
  });

  static const NotelyTheme light = NotelyTheme(
    bg: Color(0xFFFAF8F5),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F0EB),
    border: Color(0x12141C28),
    borderStrong: Color(0x1E141C28),
    text: Color(0xFF1B1427),
    text2: Color(0xAD1B1427),
    text3: Color(0x701B1427),
    text4: Color(0x471B1427),
    violet: Color(0xFFA78BFA),
    violetDeep: Color(0xFF7C5CF5),
    violetInk: Color(0xFF4C1D95),
    violetSoft: Color(0x1EA78BFA),
    violetSoft2: Color(0x33A78BFA),
    success: Color(0xFF10B981),
  );

  static const NotelyTheme dark = NotelyTheme(
    bg: Color(0xFF0E0B14),
    surface: Color(0xFF17131F),
    surface2: Color(0xFF1E1928),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x23FFFFFF),
    text: Color(0xFFF5F2FB),
    text2: Color(0xB7F5F2FB),
    text3: Color(0x7AF5F2FB),
    text4: Color(0x47F5F2FB),
    violet: Color(0xFFA78BFA),
    violetDeep: Color(0xFF7C5CF5),
    violetInk: Color(0xFFD7C6FF),
    violetSoft: Color(0x23A78BFA),
    violetSoft2: Color(0x38A78BFA),
    success: Color(0xFF10B981),
  );

  static NotelyTheme of(BuildContext context) {
    final t = Theme.of(context).extension<NotelyTheme>();
    assert(t != null, 'NotelyTheme not present in ThemeData');
    return t!;
  }

  TextStyle get displaySerif {
    final serif = TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic);
    return TextStyle(fontFamily: 'Geist').merge(serif);
  }

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
    );
  }
}
