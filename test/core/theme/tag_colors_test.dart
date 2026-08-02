import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/theme/tag_colors.dart';

void main() {
  group('TagColors.named', () {
    test('exposes the 8 design tags with exact colors', () {
      expect(TagColors.named.keys, containsAll(['School', 'Dev', 'Projects', 'Career', 'Ideas', 'Personal', 'Research', 'Travel']));
      final projects = TagColors.named['Projects']!;
      expect(projects.dot, const Color(0xFF8B5CF6));
      expect(projects.fg, const Color(0xFF5B2A8C));
      expect(projects.bg, const Color(0xFFEEE4FB));
    });
  });

  group('TagColors.resolve', () {
    test('known tag returns its named palette in light mode', () {
      final r = TagColors.resolve('Dev', Brightness.light);
      expect(r.fg, TagColors.named['Dev']!.fg);
    });

    test('unknown tag is deterministic across calls', () {
      final a = TagColors.resolve('Quantum', Brightness.light);
      final b = TagColors.resolve('Quantum', Brightness.light);
      expect(a, b);
    });

    test('unknown tag resolves into one of the named palettes', () {
      final palettes = TagColors.named.values.toSet();
      final r = TagColors.resolve('Arbitrary Name', Brightness.light);
      expect(palettes, contains((fg: r.fg, bg: r.bg, dot: r.dot)));
    });

    test('dark mode brightens fg and dims bg for named tags', () {
      final light = TagColors.resolve('Dev', Brightness.light);
      final dark = TagColors.resolve('Dev', Brightness.dark);
      expect(dark.fg, isNot(light.fg));
      expect(dark.bg, isNot(light.bg));
    });
  });
}
