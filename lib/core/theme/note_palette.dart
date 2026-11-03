import 'package:flutter/material.dart';

/// Note color labels, as inks: they mark a note's margin line and dot.
/// Order matters: notes store an index into this list.
const List<Color> kNotePalette = [
  Color(0xFF3F7D5C), // moss
  Color(0xFF2F4AA0), // ink blue
  Color(0xFFB07A1E), // ochre
  Color(0xFFB0473A), // brick
  Color(0xFF6E4A8E), // plum
  Color(0xFF3A7A8C), // slate teal
];

const List<String> kNotePaletteNames = ['Moss', 'Ink', 'Ochre', 'Brick', 'Plum', 'Teal'];
