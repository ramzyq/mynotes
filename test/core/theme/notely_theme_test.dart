import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/notely_theme.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

void main() {
  test('NotelyTheme.light uses design light tokens', () {
    expect(NotelyTheme.light.bg, const Color(0xFFF7F4EE));
    expect(NotelyTheme.light.surface, const Color(0xFFFDFBF7));
    expect(NotelyTheme.light.violet, const Color(0xFF2F4AA0));
    expect(NotelyTheme.light.violetDeep, const Color(0xFF263C85));
  });

  test('NotelyTheme.dark uses design dark tokens', () {
    expect(NotelyTheme.dark.bg, const Color(0xFF161513));
    expect(NotelyTheme.dark.surface, const Color(0xFF1C1A18));
  });

  test('buildNotelyTheme wires the extension', () {
    final t = buildNotelyTheme(Brightness.dark);
    expect(t.extension<NotelyTheme>(), isA<NotelyTheme>());
    expect(t.scaffoldBackgroundColor, NotelyTheme.dark.bg);
  });

  test('kNotePalette is the 6-color list', () {
    expect(kNotePalette, hasLength(6));
  });
}
