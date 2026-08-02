import 'package:flutter/material.dart';

typedef TagPalette = ({Color fg, Color bg, Color dot});

class TagColors {
  TagColors._();

  static const Map<String, TagPalette> named = {
    'School': (fg: Color(0xFF0E4B8C), bg: Color(0xFFE4EFFC), dot: Color(0xFF3B82F6)),
    'Dev': (fg: Color(0xFF0E5E3E), bg: Color(0xFFDEF2E6), dot: Color(0xFF10B981)),
    'Projects': (fg: Color(0xFF5B2A8C), bg: Color(0xFFEEE4FB), dot: Color(0xFF8B5CF6)),
    'Career': (fg: Color(0xFF8A4B0E), bg: Color(0xFFFBEBD9), dot: Color(0xFFF59E0B)),
    'Ideas': (fg: Color(0xFF8B2161), bg: Color(0xFFFBE4EF), dot: Color(0xFFEC4899)),
    'Personal': (fg: Color(0xFF4A4A55), bg: Color(0xFFECECEF), dot: Color(0xFF6B7280)),
    'Research': (fg: Color(0xFF0D5E6B), bg: Color(0xFFDEF1F4), dot: Color(0xFF06B6D4)),
    'Travel': (fg: Color(0xFF8E1E3E), bg: Color(0xFFFBDEE4), dot: Color(0xFFF43F5E)),
  };

  static const Map<String, TagPalette> _dark = {
    'School': (fg: Color(0xFF9EC5FF), bg: Color(0x283E82FF), dot: Color(0xFF3B82F6)),
    'Dev': (fg: Color(0xFF7DDBA9), bg: Color(0x2810B981), dot: Color(0xFF10B981)),
    'Projects': (fg: Color(0xFFD1B3FF), bg: Color(0x2DA78BFA), dot: Color(0xFF8B5CF6)),
    'Career': (fg: Color(0xFFF2C08A), bg: Color(0x28F59E0B), dot: Color(0xFFF59E0B)),
    'Ideas': (fg: Color(0xFFF5A6CE), bg: Color(0x28EC4899), dot: Color(0xFFEC4899)),
    'Personal': (fg: Color(0xFFC7C8D0), bg: Color(0x23B4B4BE), dot: Color(0xFF6B7280)),
    'Research': (fg: Color(0xFF8ED6E0), bg: Color(0x2806B6D4), dot: Color(0xFF06B6D4)),
    'Travel': (fg: Color(0xFFF59FB1), bg: Color(0x28F43F5E), dot: Color(0xFFF43F5E)),
  };

  static TagPalette resolve(String name, Brightness brightness) {
    final key = _key(name);
    final palette = brightness == Brightness.dark ? _dark : named;
    return palette[key] ?? named[key] ?? _hashAssign(name);
  }

  static String _key(String name) {
    final normalized = name.trim();
    for (final k in named.keys) {
      if (k.toLowerCase() == normalized.toLowerCase()) return k;
    }
    return normalized;
  }

  static TagPalette _hashAssign(String name) {
    var hash = 0;
    for (final code in name.toLowerCase().codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final palette = named.values.toList();
    return palette[hash % palette.length];
  }
}
