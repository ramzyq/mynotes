# Notely UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the app to Notely and restyle every screen with the "Notely — Notes List" design language (Editorial variant), adding archive, sort, multi-select, a working light/dark theme, an account sheet, and an archived view.

**Architecture:** Build a ThemeExtension design system (`lib/core/theme/`) carrying all design tokens, wire a persisted theme-mode provider into `MaterialApp`, then rebuild the notes list on top of the tokens and mechanically restyle the remaining screens. Data-layer additions (`isArchived`, batch ops, sort) live in `Note`/`NotesService`.

**Tech Stack:** Flutter/Dart, Riverpod, Firebase Firestore, `shared_preferences` (new), bundled fonts (Geist / Instrument Serif / JetBrains Mono), Material 3.

## Global Constraints

- Dart SDK `^3.10.8`; Flutter Material 3.
- Design tokens (exact values, verbatim from `docs/design/src/theme.jsx`): violet `#A78BFA`, violetDeep `#7C5CF5`, bg light `#FAF8F5` / dark `#0E0B14`, surface light `#FFFFFF` / dark `#17131F`, surface2 light `#F3F0EB` / dark `#1E1928`, text light `#1B1427` / dark `#F5F2FB`.
- Fonts: Geist (UI), Instrument Serif (display), JetBrains Mono (metadata) — **bundled assets, no network fetch at runtime**.
- Tag color taxonomy: the 8 named tags (School, Dev, Projects, Career, Ideas, Personal, Research, Travel) use their exact design colors; unknown tags hash-assign deterministically.
- The app is rebranded **Notely** (wordmark + display copy). Package name `mynotes` and repo unchanged.
- No comments in Dart code. `flutter analyze` must pass. Existing tests stay green.
- Light and dark themes must both work; default mode is **system**, persisted.
- The old note `colorIndex` palette keeps working (hoisted, not removed).

---

### Task 1: TagColors — tag palette + deterministic hash

**Files:**
- Create: `lib/core/theme/tag_colors.dart`
- Test: `test/core/theme/tag_colors_test.dart`

**Interfaces:**
- Produces: `class TagColors` with `static (Color fg, Color bg, Color dot) resolve(String name, Brightness brightness)` and `static const Map<String, ({Color fg, Color bg, Color dot})> named`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/tag_colors_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/tag_colors_test.dart`
Expected: FAIL — `tag_colors.dart` does not exist.

- [ ] **Step 3: Write implementation**

```dart
// lib/core/theme/tag_colors.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/tag_colors_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/tag_colors.dart test/core/theme/tag_colors_test.dart
git commit -m "feat: add Notely tag color taxonomy with deterministic hash"
```

---

### Task 2: NotelyTheme extension + typography + theme builder + note palette

**Files:**
- Create: `lib/core/theme/notely_tokens.dart` (the `NotelyTheme` ThemeExtension)
- Create: `lib/core/theme/notely_typography.dart`
- Create: `lib/core/theme/notely_theme.dart` (`_buildTheme` equivalent + `buildNotelyTheme(Brightness)`)
- Create: `lib/core/theme/note_palette.dart` (hoisted 6-color palette)
- Test: `test/core/theme/notely_theme_test.dart`

**Interfaces:**
- Consumes: `TagColors` (Task 1) for nothing yet — not needed here.
- Produces:
  - `class NotelyTheme extends ThemeExtension<NotelyTheme>` with `final Color bg, surface, surface2, border, borderStrong, text, text2, text3, text4, violet, violetDeep, violetInk, violetSoft, violetSoft2, success;` `static const NotelyTheme light;` `static const NotelyTheme dark;` `static NotelyTheme of(BuildContext context);` plus `copyWith` and `lerp`.
  - `TextStyle get displaySerif; TextStyle get bodyGeist;` on `NotelyTheme` for the two headline styles.
  - `ThemeData buildNotelyTheme(Brightness brightness)`
  - `const List<Color> kNotePalette = [...]` (the existing 6 colors).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/notely_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/theme/notely_theme.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

void main() {
  test('NotelyTheme.light uses design light tokens', () {
    expect(NotelyTheme.light.bg, const Color(0xFFFAF8F5));
    expect(NotelyTheme.light.surface, const Color(0xFFFFFFFF));
    expect(NotelyTheme.light.violet, const Color(0xFFA78BFA));
    expect(NotelyTheme.light.violetDeep, const Color(0xFF7C5CF5));
  });

  test('NotelyTheme.dark uses design dark tokens', () {
    expect(NotelyTheme.dark.bg, const Color(0xFF0E0B14));
    expect(NotelyTheme.dark.surface, const Color(0xFF17131F));
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/notely_theme_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Write the tokens file**

```dart
// lib/core/theme/notely_tokens.dart
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
```

- [ ] **Step 4: Write the typography file**

```dart
// lib/core/theme/notely_typography.dart
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
```

- [ ] **Step 5: Write the theme builder**

```dart
// lib/core/theme/notely_theme.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/notely_typography.dart';

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
```

- [ ] **Step 6: Write the palette file**

```dart
// lib/core/theme/note_palette.dart
import 'package:flutter/material.dart';

const List<Color> kNotePalette = [
  Color(0xFF86E7C8),
  Color(0xFF8AA7FF),
  Color(0xFFFFC46B),
  Color(0xFFFF8FA3),
  Color(0xFF9D93FF),
  Color(0xFF67D3FF),
];
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/core/theme/notely_theme_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/theme/notely_tokens.dart lib/core/theme/notely_typography.dart lib/core/theme/notely_theme.dart lib/core/theme/note_palette.dart test/core/theme/notely_theme_test.dart
git commit -m "feat: add Notely theme extension, typography, and theme builder"
```

---

### Task 3: Fonts + shared_preferences + theme-mode provider + app wiring

**Files:**
- Create: `assets/fonts/` (8 font files)
- Modify: `pubspec.yaml` (add `shared_preferences`, font assets)
- Create: `lib/core/providers/theme_mode_provider.dart`
- Modify: `lib/app.dart` (use `themeModeProvider`, remove `AppThemeScope`, use `buildNotelyTheme`)
- Modify: `test/widget_test.dart` (new branding copy)
- Test: `test/core/providers/theme_mode_provider_test.dart`

**Interfaces:**
- Consumes: `buildNotelyTheme(Brightness)` (Task 2).
- Produces: `final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ...)` with `.notifier.toggle()` and `.notifier.setSystem()` — actually a `NotifierProvider`; expose `class ThemeModeNotifier extends Notifier<ThemeMode>` with `void set(ThemeMode mode)`. Later tasks read it for the account sheet.

- [ ] **Step 1: Download the fonts**

Run this PowerShell (requires network). Font files land in `assets/fonts/`:

```powershell
New-Item -ItemType Directory -Force -Path "assets\fonts" | Out-Null
$fonts = @{
  'Geist-Regular.ttf' = 'https://github.com/google/fonts/raw/main/ofl/geist/Geist%5Bwght%5D.ttf'
  'InstrumentSerif-Regular.ttf' = 'https://github.com/google/fonts/raw/main/ofl/instrumentserif/InstrumentSerif-Regular.ttf'
  'InstrumentSerif-Italic.ttf' = 'https://github.com/google/fonts/raw/main/ofl/instrumentserif/InstrumentSerif-Italic.ttf'
  'JetBrainsMono-Regular.ttf' = 'https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf'
}
foreach ($name in $fonts.Keys) {
  Invoke-WebRequest -Uri $fonts[$name] -OutFile "assets\fonts\$name"
}
Get-ChildItem "assets\fonts" | Select-Object Name, Length
```

Note: Geist and JetBrains Mono are variable-weight fonts on Google Fonts. The single variable file serves weights 100–900, so we declare one asset per family and Flutter uses it for all weights. If the Geist variable URL 404s, use the CSS API (`https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&display=swap`), extract the `url(…)` for the ttf/woff2, and download it. Verify each file is non-empty.

- [ ] **Step 2: Add dependency + fonts to pubspec**

In `pubspec.yaml` under `dependencies:` add:

```yaml
  shared_preferences: ^2.3.0
```

Under the `flutter:` section add:

```yaml
  fonts:
    - family: Geist
      fonts:
        - asset: assets/fonts/Geist-Regular.ttf
    - family: Instrument Serif
      fonts:
        - asset: assets/fonts/InstrumentSerif-Regular.ttf
        - asset: assets/fonts/InstrumentSerif-Italic.ttf
          style: italic
    - family: JetBrains Mono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
```

Then run `flutter pub get`.

- [ ] **Step 3: Write the failing test**

```dart
// test/core/providers/theme_mode_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system and persists changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);

    container.read(themeModeProvider.notifier).set(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notely.themeMode'), 'dark');
  });

  test('restores persisted value', () async {
    SharedPreferences.setMockInitialValues({'notely.themeMode': 'light'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/core/providers/theme_mode_provider_test.dart`
Expected: FAIL — provider missing.

- [ ] **Step 5: Write the provider**

```dart
// lib/core/providers/theme_mode_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'notely.themeMode';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_prefsKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void set(ThemeMode mode) {
    state = mode;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefsKey, mode.name);
    });
  }
}
```

Note: a `Notifier.build()` that returns `Future` works because `Notifier` supports async build via `AsyncNotifier` only. For a synchronous `Notifier`, `build()` must return `ThemeMode` synchronously. Use this instead:

```dart
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeModeNotifier();

  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = switch (prefs.getString(_prefsKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
```

- [ ] **Step 6: Rewrite the test for the synchronous Notifier**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system and persists changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);

    await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notely.themeMode'), 'dark');
  });

  test('restores persisted value', () async {
    SharedPreferences.setMockInitialValues({'notely.themeMode': 'light'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/core/providers/theme_mode_provider_test.dart`
Expected: PASS.

- [ ] **Step 8: Wire app.dart**

Replace the contents of `lib/app.dart` so that:
- imports drop `theme_toggle_button.dart`, add `core/providers/theme_mode_provider.dart` and `core/theme/notely_theme.dart`.
- `_buildTheme` is deleted; use `buildNotelyTheme`.
- `MyApp` becomes a `ConsumerWidget`:

```dart
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notely',
      theme: buildNotelyTheme(Brightness.light),
      darkTheme: buildNotelyTheme(Brightness.dark),
      themeMode: themeMode,
      home: const AuthenticationWrapper(),
    );
  }
}
```

- Keep `AuthenticationWrapper` unchanged (it still returns `LoginView` / `VerifyEmailView` / `NotesHomeView`).

- [ ] **Step 9: Update widget_test.dart**

`test/widget_test.dart` asserts `find.text('Note Log')` and `find.text('Dark notes workspace for ideas and drafts')`. The login view is restyled in Task 14; update only the theme expectations now:

```dart
expect(find.text('Notely'), findsWidgets);
```

And delete the `find.text('Dark notes workspace for ideas and drafts')` assertion (the login copy changes in Task 14). Run `flutter test test/widget_test.dart` — it should still pass (login screen renders wordmark).

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/providers/theme_mode_provider.dart lib/app.dart test/widget_test.dart test/core/providers/theme_mode_provider_test.dart assets/fonts
git commit -m "feat: add theme mode provider, bundle fonts, wire Notely theme into app"
```

---

### Task 4: Shared design widgets (TagPill, NotelyAvatar, NotelyWordmark, NotelySheet)

**Files:**
- Create: `lib/core/theme/widgets/tag_pill.dart`
- Create: `lib/core/theme/widgets/notely_avatar.dart`
- Create: `lib/core/theme/widgets/notely_wordmark.dart`
- Create: `lib/core/theme/widgets/notely_sheet.dart`
- Test: `test/core/theme/widgets/notely_widgets_test.dart`

**Interfaces:**
- Consumes: `NotelyTheme` (Task 2), `TagColors` (Task 1).
- Produces:
  - `class TagPill extends StatelessWidget` with `const TagPill({super.key, required this.name, this.small = false, this.outlined = false, this.style = TagPillStyle.pill})`; `enum TagPillStyle { pill, dot, outlined }`. Renders using `TagColors.resolve(name, brightness)` + `NotelyTheme`.
  - `class NotelyAvatar extends StatelessWidget` with `const NotelyAvatar({super.key, this.size = 32, required this.initial, this.ring = false})`.
  - `class NotelyWordmark extends StatelessWidget` with `const NotelyWordmark({super.key, this.size = 18})`.
  - `class NotelySheet extends StatelessWidget` with `const NotelySheet({super.key, required this.child})` — grabber + padding container, to be used inside `showModalBottomSheet`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/widgets/notely_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/theme/widgets/notely_avatar.dart';
import 'package:mynotes/core/theme/widgets/notely_wordmark.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: child));

void main() {
  testWidgets('TagPill renders its name', (tester) async {
    await tester.pumpWidget(_wrap(const TagPill(name: 'Dev')));
    expect(find.text('Dev'), findsOneWidget);
  });

  testWidgets('NotelyWordmark renders text', (tester) async {
    await tester.pumpWidget(_wrap(const NotelyWordmark()));
    expect(find.text('Notely'), findsOneWidget);
  });

  testWidgets('NotelyAvatar renders initial', (tester) async {
    await tester.pumpWidget(_wrap(const NotelyAvatar(initial: 'M')));
    expect(find.text('M'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/widgets/notely_widgets_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Write TagPill**

```dart
// lib/core/theme/widgets/tag_pill.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/tag_colors.dart';

enum TagPillStyle { pill, dot, outlined }

class TagPill extends StatelessWidget {
  final String name;
  final bool small;
  final TagPillStyle style;

  const TagPill({
    super.key,
    required this.name,
    this.small = false,
    this.style = TagPillStyle.pill,
  });

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final palette = TagColors.resolve(name, brightness);

    if (style == TagPillStyle.dot) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: palette.dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: notely.text2, letterSpacing: -0.1)),
        ],
      );
    }

    if (style == TagPillStyle.outlined) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 1 : 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.fg.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: palette.dot, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(name, style: TextStyle(fontSize: small ? 10 : 11, fontWeight: FontWeight.w500, color: palette.fg)),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: small ? 10 : 11, fontWeight: FontWeight.w600, color: palette.fg, height: 1.2),
      ),
    );
  }
}
```

- [ ] **Step 4: Write NotelyAvatar + NotelyWordmark + NotelySheet**

```dart
// lib/core/theme/widgets/notely_avatar.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class NotelyAvatar extends StatelessWidget {
  final double size;
  final String initial;
  final bool ring;

  const NotelyAvatar({super.key, this.size = 32, required this.initial, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final char = initial.isNotEmpty ? initial.substring(0, 1).toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC4A7FF), Color(0xFF8B5CF6), Color(0xFF5B21B6)],
          stops: [0, 0.55, 1],
        ),
        boxShadow: ring
            ? [BoxShadow(color: notely.surface, spreadRadius: 2), BoxShadow(color: notely.violet, spreadRadius: 3.5)]
            : const [BoxShadow(color: Color(0x403C1E78), blurRadius: 1, offset: Offset(0, 1))],
      ),
      child: Text(char, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.42, letterSpacing: -0.2)),
    );
  }
}
```

```dart
// lib/core/theme/widgets/notely_wordmark.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class NotelyWordmark extends StatelessWidget {
  final double size;

  const NotelyWordmark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size + 4,
          height: size + 4,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC4A7FF), Color(0xFF7C3AED)],
            ),
          ),
          child: CustomPaint(size: Size(size, size), painter: _NotelyNPainter()),
        ),
        const SizedBox(width: 7),
        Text('Notely', style: TextStyle(fontFamily: 'Geist', fontSize: size, fontWeight: FontWeight.w600, color: notely.text, letterSpacing: -0.4)),
      ],
    );
  }
}

class _NotelyNPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.71)
      ..lineTo(size.width * 0.29, size.height * 0.33)
      ..lineTo(size.width * 0.71, size.height * 0.71)
      ..lineTo(size.width * 0.71, size.height * 0.33);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

```dart
// lib/core/theme/widgets/notely_sheet.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class NotelySheet extends StatelessWidget {
  final Widget child;

  const NotelySheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: notely.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/theme/widgets/notely_widgets_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/widgets test/core/theme/widgets/notely_widgets_test.dart
git commit -m "feat: add shared Notely widgets (TagPill, Avatar, Wordmark, Sheet)"
```

---

### Task 5: Note model — isArchived

**Files:**
- Modify: `lib/features/notes/data/note.dart`
- Test: `test/features/notes/data/note_archive_test.dart`

**Interfaces:**
- Consumes: `Note` (existing).
- Produces: `bool isArchived` field (default `false`), serialized in `toMap`/`fromFirestore`, supported in `copyWith`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/data/note_archive_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/note.dart';

Note _note() => Note(
      id: 'n1',
      title: 'T',
      content: 'C',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

void main() {
  test('isArchived defaults to false', () {
    expect(_note().isArchived, false);
  });

  test('copyWith updates isArchived', () {
    expect(_note().copyWith(isArchived: true).isArchived, true);
  });

  test('toMap round-trips isArchived', () {
    final archived = _note().copyWith(isArchived: true);
    final map = archived.toMap();
    expect(map['isArchived'], true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/data/note_archive_test.dart`
Expected: FAIL — `isArchived` undefined.

- [ ] **Step 3: Implement**

In `lib/features/notes/data/note.dart`:
- Add field after `final bool isPinned;`:
  ```dart
  final bool isArchived;
  ```
- Add to constructor after `required this.isPinned,`:
  ```dart
  this.isArchived = false,
  ```
- In both `fromFirestore` branches (encryptionVersion == 0 and >= 1), add after `isPinned:`:
  ```dart
  isArchived: (data['isArchived'] as bool?) ?? false,
  ```
- In `copyWith`, add param after `bool? isPinned,`:
  ```dart
  bool? isArchived,
  ```
  and in the constructor call:
  ```dart
  isArchived: isArchived ?? this.isArchived,
  ```
- In `toMap`, add after `'isPinned': isPinned,`:
  ```dart
  'isArchived': isArchived,
  ```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/data/note_archive_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full test suite + analyzer**

Run: `flutter test` and `flutter analyze`
Expected: all green, no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/notes/data/note.dart test/features/notes/data/note_archive_test.dart
git commit -m "feat: add isArchived to Note model"
```

---

### Task 6: NoteSort + NotesService archive/batch methods

**Files:**
- Create: `lib/features/notes/data/note_sort.dart`
- Modify: `lib/features/notes/data/notes_service.dart`
- Test: `test/features/notes/data/note_sort_test.dart`

**Interfaces:**
- Consumes: `Note` (with `isArchived`, Task 5).
- Produces:
  - `enum NoteSort { updated, created, titleAZ, tag }`
  - `Comparator<Note> noteComparator(NoteSort sort)`
  - On `NotesService`: `Future<void> setArchived({required String uid, required Note note, required bool archived})`, `Future<void> archiveMany({required String uid, required List<Note> notes})`, `Future<void> deleteMany({required String uid, required List<Note> notes})`, `Future<void> setPinnedMany({required String uid, required List<Note> notes, required bool pinned})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/data/note_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';

Note _n(String id, {DateTime? updated, DateTime? created, String? title, List<String>? tags}) =>
    Note(
      id: id,
      title: title,
      content: 'c',
      colorIndex: 0,
      isPinned: false,
      createdAt: created ?? DateTime(2024, 1, 1),
      updatedAt: updated ?? DateTime(2024, 1, 1),
      tags: tags,
    );

void main() {
  test('updated sorts newest first', () {
    final list = [_n('a', updated: DateTime(2024, 1, 2)), _n('b', updated: DateTime(2024, 1, 1))];
    list.sort(noteComparator(NoteSort.updated));
    expect(list.first.id, 'a');
  });

  test('created sorts by createdAt', () {
    final list = [_n('a', created: DateTime(2024, 1, 1)), _n('b', created: DateTime(2024, 1, 2))];
    list.sort(noteComparator(NoteSort.created));
    expect(list.first.id, 'b');
  });

  test('titleAZ sorts alphabetically case-insensitive', () {
    final list = [_n('a', title: 'Banana'), _n('b', title: 'apple')];
    list.sort(noteComparator(NoteSort.titleAZ));
    expect(list.first.id, 'b');
  });

  test('tag sorts by first tag then title', () {
    final list = [
      _n('a', title: 'Zebra', tags: ['Dev']),
      _n('b', title: 'Alpha', tags: ['Career']),
    ];
    list.sort(noteComparator(NoteSort.tag));
    expect(list.first.id, 'b');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/data/note_sort_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Write note_sort.dart**

```dart
// lib/features/notes/data/note_sort.dart
import 'package:mynotes/features/notes/data/note.dart';

enum NoteSort { updated, created, titleAZ, tag }

Comparator<Note> noteComparator(NoteSort sort) {
  switch (sort) {
    case NoteSort.updated:
      return (a, b) => b.updatedAt.compareTo(a.updatedAt);
    case NoteSort.created:
      return (a, b) => b.createdAt.compareTo(a.createdAt);
    case NoteSort.titleAZ:
      return (a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
    case NoteSort.tag:
      return (a, b) {
        final at = (a.tags?.firstOrNull ?? '').toLowerCase();
        final bt = (b.tags?.firstOrNull ?? '').toLowerCase();
        final byTag = at.compareTo(bt);
        if (byTag != 0) return byTag;
        return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
      };
  }
}
```

- [ ] **Step 4: Add service methods**

In `lib/features/notes/data/notes_service.dart`, after `togglePin` add:

```dart
  Future<void> setArchived({
    required String uid,
    required Note note,
    required bool archived,
  }) async {
    await _notesCollection(uid).doc(note.id).update({
      'isArchived': archived,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> archiveMany({
    required String uid,
    required List<Note> notes,
  }) async {
    final batch = firestore.batch();
    for (final note in notes) {
      batch.update(_notesCollection(uid).doc(note.id), {
        'isArchived': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  Future<void> deleteMany({
    required String uid,
    required List<Note> notes,
  }) async {
    for (final note in notes) {
      await deleteNote(uid: uid, noteId: note.id);
    }
  }

  Future<void> setPinnedMany({
    required String uid,
    required List<Note> notes,
    required bool pinned,
  }) async {
    final batch = firestore.batch();
    for (final note in notes) {
      batch.update(_notesCollection(uid).doc(note.id), {
        'isPinned': pinned,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }
```

Note: `firstOrNull` requires Dart 3; it's in `package:collection`'s extension but also available via `Iterable.firstOrNull` from Dart 3.0 core? It's in `dart:core` since 3.0 as an extension on `Iterable`. Safe.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/notes/data/note_sort_test.dart`
Expected: PASS.

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/data/note_sort.dart lib/features/notes/data/notes_service.dart test/features/notes/data/note_sort_test.dart
git commit -m "feat: add sort comparators and archive/batch operations"
```

---

### Task 7: Notes home — header, search, filter chips, sort menu

**Files:**
- Create: `lib/features/notes/presentation/widgets/list_header.dart`
- Modify: `lib/features/notes/presentation/notes_home_view.dart` (start wiring; full assembly in Task 10)
- Test: `test/features/notes/presentation/list_header_test.dart`

**Interfaces:**
- Consumes: `NotelyTheme`, `NotelyWordmark`, `NotelyAvatar`, `NoteSort`, `Note`, `AuthUser`.
- Produces:
  - `class ListHeader extends StatelessWidget` with:
    ```dart
    const ListHeader({
      super.key,
      required this.userName,
      required this.noteCount,
      required this.onOpenAccount,
      required this.onToggleSelect,
      required this.selectMode,
    });
    ```
    Renders wordmark + select-toggle + avatar row, then the serif "Your notes, `userName`." title + `N notes · synced to Firestore` subtitle.
  - `class NoteSearchField extends StatelessWidget` with `const NoteSearchField({super.key, required this.controller, required this.onChanged})`.
  - `class FilterChips extends StatelessWidget` with `const FilterChips({super.key, required this.active, required this.pinnedCount, required this.onChanged})` where `active` is one of `'All' | 'Pinned' | 'Recent'`.
  - `class SortMenu extends StatelessWidget` with `const SortMenu({super.key, required this.sort, required this.onChanged})` using `NoteSort`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/list_header_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';
import 'package:mynotes/features/notes/presentation/widgets/list_header.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: child));

void main() {
  testWidgets('header shows personalized serif title', (tester) async {
    await tester.pumpWidget(_wrap(ListHeader(
      userName: 'Maya',
      noteCount: 3,
      onOpenAccount: () {},
      onToggleSelect: () {},
      selectMode: false,
    )));
    expect(find.textContaining('Maya'), findsOneWidget);
  });

  testWidgets('filter chips respond to taps', (tester) async {
    String? chosen;
    await tester.pumpWidget(_wrap(FilterChips(active: 'All', pinnedCount: 1, onChanged: (v) => chosen = v)));
    await tester.tap(find.text('Recent'));
    expect(chosen, 'Recent');
  });

  testWidgets('sort menu opens and selects', (tester) async {
    NoteSort? chosen;
    await tester.pumpWidget(_wrap(SortMenu(sort: NoteSort.updated, onChanged: (v) => chosen = v)));
    await tester.tap(find.text('Updated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title (A–Z)'));
    expect(chosen, NoteSort.titleAZ);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/list_header_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Write list_header.dart**

```dart
// lib/features/notes/presentation/widgets/list_header.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_avatar.dart';
import 'package:mynotes/core/theme/widgets/notely_wordmark.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';

class ListHeader extends StatelessWidget {
  final String userName;
  final int noteCount;
  final VoidCallback onOpenAccount;
  final VoidCallback onToggleSelect;
  final bool selectMode;

  const ListHeader({
    super.key,
    required this.userName,
    required this.noteCount,
    required this.onOpenAccount,
    required this.onToggleSelect,
    required this.selectMode,
  });

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const NotelyWordmark(size: 17),
            Row(
              children: [
                _CircleIconButton(
                  icon: selectMode ? Icons.close : Icons.check,
                  onTap: onToggleSelect,
                ),
                const SizedBox(width: 8),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onOpenAccount,
                  child: NotelyAvatar(initial: userName, ring: true),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Your notes, ',
                style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 42, height: 1.02, letterSpacing: -1.2, color: notely.text),
              ),
              TextSpan(
                text: '$userName.',
                style: TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic, fontSize: 42, height: 1.02, letterSpacing: -1.2, color: notely.violet),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: notely.success,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: notely.success.withValues(alpha: 0.18), blurRadius: 0, spreadRadius: 3)],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$noteCount notes · synced to Firestore',
              style: TextStyle(fontSize: 13, color: notely.text3, letterSpacing: -0.1),
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: notely.surface, border: Border.all(color: notely.border), shape: BoxShape.circle),
        child: Icon(icon, size: 19, color: notely.text2),
      ),
    );
  }
}

class NoteSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const NoteSearchField({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search notes, tags, content…',
        prefixIcon: Icon(Icons.search, color: notely.text3),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: 16, color: notely.text3),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  final String active;
  final int pinnedCount;
  final ValueChanged<String> onChanged;

  const FilterChips({super.key, required this.active, required this.pinnedCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    Widget chip(String label, {String? trailing}) {
      final isActive = active == label;
      return InkWell(
        onTap: () => onChanged(label),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? notely.violet : Colors.transparent,
            border: Border.all(color: isActive ? Colors.transparent : notely.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  color: isActive ? Colors.white : notely.text2,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 5),
                Text(trailing, style: TextStyle(fontSize: 12, color: isActive ? Colors.white.withValues(alpha: 0.85) : notely.text3)),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('All'),
        const SizedBox(width: 6),
        chip('Pinned', trailing: '$pinnedCount'),
        const SizedBox(width: 6),
        chip('Recent'),
      ],
    );
  }
}

class SortMenu extends StatefulWidget {
  final NoteSort sort;
  final ValueChanged<NoteSort> onChanged;

  const SortMenu({super.key, required this.sort, required this.onChanged});

  @override
  State<SortMenu> createState() => _SortMenuState();
}

class _SortMenuState extends State<SortMenu> {
  final _menuKey = GlobalKey();
  bool _open = false;

  String get _label => switch (widget.sort) {
        NoteSort.updated => 'Updated',
        NoteSort.created => 'Created',
        NoteSort.titleAZ => 'Title (A–Z)',
        NoteSort.tag => 'Tag',
      };

  void _toggle() {
    setState(() => _open = !_open);
  }

  void _choose(NoteSort sort) {
    setState(() => _open = false);
    widget.onChanged(sort);
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        InkWell(
          key: _menuKey,
          onTap: _toggle,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: notely.border), borderRadius: BorderRadius.circular(9)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, size: 14, color: notely.text2),
                const SizedBox(width: 4),
                Text(_label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: notely.text2)),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 14, color: notely.text3),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          Material(
            color: notely.surface,
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            shadowColor: const Color(0x1F141028),
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(border: Border.all(color: notely.border), borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: NoteSort.values.map((sort) {
                  final isActive = widget.sort == sort;
                  return InkWell(
                    onTap: () => _choose(sort),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      color: isActive ? notely.violetSoft : Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_labelFor(sort), style: TextStyle(fontSize: 13, color: notely.text)),
                          if (isActive) Icon(Icons.check, size: 14, color: notely.violet),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _labelFor(NoteSort sort) => switch (sort) {
        NoteSort.updated => 'Updated',
        NoteSort.created => 'Created',
        NoteSort.titleAZ => 'Title (A–Z)',
        NoteSort.tag => 'Tag',
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/list_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/list_header.dart test/features/notes/presentation/list_header_test.dart
git commit -m "feat: add Notely list header, search field, filter chips, and sort menu"
```

---

### Task 8: NoteCard — swipe-to-archive, tag pills, status icons

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_card.dart`
- Test: `test/features/notes/presentation/note_card_test.dart`

**Interfaces:**
- Consumes: `NotelyTheme`, `TagPill`, `Note`, `NoteSort` (not needed), `AuthUser` (for lock routing callback — passed as callback instead).
- Produces:
  ```dart
  class NoteCard extends StatefulWidget {
    const NoteCard({
      super.key,
      required this.note,
      required this.selectMode,
      required this.selected,
      required this.onSelect,
      required this.onPin,
      required this.onArchive,
      required this.onOpen,
      required this.onTagTap,
      required this.relativeTime,
    });
  }
  ```
  `relativeTime` is a `String` computed by the caller. Renders the swipeable card with `TagPill`s for `note.tags` and status icons (locked / self-destruct / read-once / shared) before `relativeTime`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/note_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_card.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: child));

Note _note() => Note(
      id: 'n1',
      title: 'Flutter state management',
      content: 'Riverpod wins on compile-time safety.',
      colorIndex: 0,
      isPinned: true,
      tags: const ['Dev', 'Projects'],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
    );

void main() {
  testWidgets('renders title, preview, tags, and time', (tester) async {
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note(),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () {},
      onTagTap: (_) {},
      relativeTime: '12 min',
    )));
    expect(find.text('Flutter state management'), findsOneWidget);
    expect(find.text('Dev'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
  });

  testWidgets('tap calls onOpen when not in select mode', (tester) async {
    var opened = false;
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note(),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () => opened = true,
      onTagTap: (_) {},
      relativeTime: '1 h',
    )));
    await tester.tap(find.text('Flutter state management'));
    expect(opened, true);
  });

  testWidgets('swiping left reveals archive action', (tester) async {
    await tester.pumpWidget(_wrap(NoteCard(
      note: _note(),
      selectMode: false,
      selected: false,
      onSelect: () {},
      onPin: () {},
      onArchive: () {},
      onOpen: () {},
      onTagTap: (_) {},
      relativeTime: '1 h',
    )));
    await tester.drag(find.byType(NoteCard), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/note_card_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Write note_card.dart**

```dart
// lib/features/notes/presentation/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';
import 'package:mynotes/features/notes/data/note.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final bool selectMode;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onOpen;
  final ValueChanged<String> onTagTap;
  final String relativeTime;

  const NoteCard({
    super.key,
    required this.note,
    required this.selectMode,
    required this.selected,
    required this.onSelect,
    required this.onPin,
    required this.onArchive,
    required this.onOpen,
    required this.onTagTap,
    required this.relativeTime,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  static const double _maxSwipe = 140;
  static const double _threshold = 72;

  double _dx = 0;
  bool _dragging = false;
  double _startX = 0;
  double _lastDx = 0;

  void _onPointerDown(PointerDownEvent e) {
    if (widget.selectMode) return;
    _startX = e.position.dx;
    _lastDx = _dx;
    setState(() => _dragging = true);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_dragging) return;
    final d = e.position.dx - _startX + _lastDx;
    setState(() => _dx = d.clamp(-_maxSwipe - 20, 0).toDouble());
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    if (_dx < -_threshold) {
      setState(() => _dx = -_maxSwipe);
    } else {
      setState(() => _dx = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final note = widget.note;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x00FFFFFF), Color(0xFFFFE2E2), Color(0xFFFCA5A5)],
                  stops: [0.3, 0.5, 1],
                ),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: InkWell(
                onTap: widget.onArchive,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.archive_outlined, color: const Color(0xFF7F1D1D), size: 18),
                    const SizedBox(width: 6),
                    Text('Archive', style: TextStyle(color: const Color(0xFF7F1D1D), fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dx, 0, 0),
            decoration: BoxDecoration(
              color: notely.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.selected ? notely.violet : notely.border, width: widget.selected ? 2 : 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: InkWell(
              onTap: widget.selectMode ? widget.onSelect : widget.onOpen,
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.selectMode) ...[
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.selected ? notely.violet : Colors.transparent,
                            border: Border.all(color: widget.selected ? notely.violet : notely.borderStrong, width: 1.5),
                          ),
                          child: widget.selected ? Icon(Icons.check, size: 12, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          note.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Geist', fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.28, letterSpacing: -0.32),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onPin,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            size: 14,
                            color: note.isPinned ? notely.violet : notely.text4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Geist', fontSize: 13.25, height: 1.45, letterSpacing: -0.15, color: notely.text3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            for (final tag in note.tags ?? const <String>[])
                              GestureDetector(
                                onTap: () => widget.onTagTap(tag),
                                child: TagPill(name: tag, small: true),
                              ),
                          ],
                        ),
                      ),
                      if (note.isLocked) ...[
                        Icon(Icons.lock_outline, size: 12, color: notely.text4),
                        const SizedBox(width: 4),
                      ],
                      if (note.selfDestructAt != null) ...[
                        Icon(Icons.timer_outlined, size: 12, color: notely.text4),
                        const SizedBox(width: 4),
                      ],
                      if (note.selfDestructOnRead) ...[
                        Icon(Icons.visibility_off_outlined, size: 12, color: notely.text4),
                        const SizedBox(width: 4),
                      ],
                      if ((note.collaborators ?? const <String>[]).isNotEmpty) ...[
                        Icon(Icons.group_outlined, size: 12, color: notely.text4),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        widget.relativeTime,
                        style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: notely.text4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/note_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/note_card.dart test/features/notes/presentation/note_card_test.dart
git commit -m "feat: add Notely note card with swipe-to-archive and tag pills"
```

---

### Task 9: FAB, empty state, toast, and the wiki-link preview helper

**Files:**
- Create: `lib/features/notes/presentation/widgets/home_fab.dart`
- Create: `lib/features/notes/presentation/widgets/empty_state.dart`
- Create: `lib/features/notes/presentation/widgets/note_preview.dart`
- Test: `test/features/notes/presentation/home_fab_empty_test.dart`

**Interfaces:**
- Consumes: `NotelyTheme`, `Note` (for preview links), `NoteCard` (no).
- Produces:
  - `class HomeFab extends StatelessWidget` with `const HomeFab({super.key, required this.onPressed})` — centered bottom pill.
  - `class EmptyState extends StatelessWidget` with `const EmptyState({super.key, required this.query, required this.activeTag, required this.onCreate})`.
  - `Widget buildNotePreview(BuildContext context, Note note, List<Note> allNotes, void Function(Note) onOpenNote)` — port of `_buildLinkPreview` (parses `[[links]]`), recolored to violetInk.
  - `void showArchiveToast(BuildContext context, VoidCallback onUndo)` — bottom pill toast with Undo.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/home_fab_empty_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/features/notes/presentation/widgets/empty_state.dart';
import 'package:mynotes/features/notes/presentation/widgets/home_fab.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildNotelyTheme(Brightness.light), home: Scaffold(body: child));

void main() {
  testWidgets('HomeFab renders label', (tester) async {
    await tester.pumpWidget(_wrap(const HomeFab(onPressed: null)));
    expect(find.text('New note'), findsOneWidget);
  });

  testWidgets('EmptyState shows create button for no query', (tester) async {
    await tester.pumpWidget(_wrap(EmptyState(query: '', activeTag: null, onCreate: () {})));
    expect(find.text('Start writing'), findsOneWidget);
  });

  testWidgets('EmptyState search variant hides create button', (tester) async {
    await tester.pumpWidget(_wrap(EmptyState(query: 'xyz', activeTag: null, onCreate: () {})));
    expect(find.text('Start writing'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/home_fab_empty_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Write the widgets**

```dart
// lib/features/notes/presentation/widgets/home_fab.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class HomeFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const HomeFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Positioned(
      left: 40,
      right: 40,
      bottom: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA78BFA), Color(0xFF7C5CF5)]),
              boxShadow: const [BoxShadow(color: Color(0x6B7C5CF5), blurRadius: 30, offset: Offset(0, 10)), BoxShadow(color: Color(0x337C5CF5), blurRadius: 6, offset: Offset(0, 2))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 9),
                Text(
                  'New note',
                  style: TextStyle(color: Colors.white, fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/features/notes/presentation/widgets/empty_state.dart
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

class EmptyState extends StatelessWidget {
  final String query;
  final String? activeTag;
  final VoidCallback onCreate;

  const EmptyState({super.key, required this.query, required this.activeTag, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final hasQuery = query.trim().isNotEmpty;
    final title = hasQuery ? 'No notes match "$query"' : 'A blank page awaits.';
    final subtitle = hasQuery
        ? 'Try a different search, or clear filters to see everything.'
        : 'Capture a thought, a lecture, a link — Notely syncs it across your devices.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StackedCardsIllustration(notely: notely),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 24, letterSpacing: -0.5, color: notely.text)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: notely.text3, height: 1.4)),
            if (!hasQuery) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Start writing'),
                style: FilledButton.styleFrom(backgroundColor: notely.violet, foregroundColor: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StackedCardsIllustration extends StatelessWidget {
  final NotelyTheme notely;
  const _StackedCardsIllustration({required this.notely});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 96,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: 8 + i * 8,
              top: 6 + i * 6,
              child: Transform.rotate(
                angle: (-6 + i * 5) * 3.14159 / 180,
                child: Container(
                  width: 80,
                  height: 68,
                  decoration: BoxDecoration(
                    color: i == 2 ? notely.surface : notely.surface2,
                    border: Border.all(color: notely.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/notes/presentation/widgets/note_preview.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/notes/data/note.dart';

final _linkRegex = RegExp(r'\[\[([^\]]+)\]\]');

Widget buildNotePreview(
  BuildContext context,
  Note note,
  List<Note> allNotes,
  void Function(Note) onOpenNote,
) {
  final notely = NotelyTheme.of(context);
  final text = note.previewText;
  final matches = _linkRegex.allMatches(text).toList();
  if (matches.isEmpty) {
    return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.25, height: 1.45, letterSpacing: -0.15, color: notely.text3));
  }

  final existingTitles = allNotes.map((n) => n.title?.trim()).whereType<String>().toSet();
  final spans = <TextSpan>[];
  var lastEnd = 0;
  for (final match in matches) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    final title = match.group(1)!.trim();
    final exists = existingTitles.contains(title);
    spans.add(TextSpan(
      text: title,
      style: TextStyle(
        color: exists ? notely.violetInk : notely.text4,
        decoration: exists ? TextDecoration.underline : TextDecoration.lineThrough,
        decorationColor: exists ? notely.violetInk : notely.text4,
        fontWeight: FontWeight.w500,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          final target = allNotes.where((n) => n.title?.trim() == title).firstOrNull;
          if (target != null) onOpenNote(target);
        },
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }
  return Text.rich(TextSpan(children: spans), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.25, height: 1.45, letterSpacing: -0.15, color: notely.text3));
}

void showArchiveToast(BuildContext context, VoidCallback onUndo) {
  final notely = NotelyTheme.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF1B1427),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    content: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Note archived', style: TextStyle(color: Colors.white, fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        InkWell(onTap: onUndo, child: Text('Undo', style: TextStyle(color: notely.violet, fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    ),
  ));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/home_fab_empty_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/home_fab.dart lib/features/notes/presentation/widgets/empty_state.dart lib/features/notes/presentation/widgets/note_preview.dart test/features/notes/presentation/home_fab_empty_test.dart
git commit -m "feat: add Notely FAB, empty state, and wiki-link preview widgets"
```

---

### Task 10: Rebuild notes_home_view (assembly)

**Files:**
- Rewrite: `lib/features/notes/presentation/notes_home_view.dart`
- Test: `test/features/notes/presentation/notes_home_view_test.dart`

**Interfaces:**
- Consumes: all widgets from Tasks 7–9, `NoteSort`/`noteComparator` (Task 6), `NotesService` methods (Task 6), `authServiceProvider`, `shareServiceProvider`, `notesProvider`, `sharedNotesProvider`, `AuthUser`, `Note`.
- Produces: `NotesHomeView` keeps its exact public API (`NotesHomeView({super.key, required this.authUser})`) so `app.dart` and `LockScreen` routing are unaffected.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/notes_home_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/notes_home_view.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';

AuthUser _user() => const AuthUser(uid: 'u1', email: 'maya@example.com', displayName: 'Maya', isEmailVerified: true);

Note _n(String id, String title, {bool pinned = false, List<String>? tags}) => Note(
      id: id,
      title: title,
      content: 'content $id',
      colorIndex: 0,
      isPinned: pinned,
      tags: tags,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
    );

Widget _wrap() => ProviderScope(
      overrides: [
        notesProvider.overrideWith((ref, uid) => Stream.value([_n('a', 'Alpha', pinned: true), _n('b', 'Beta', tags: const ['Dev'])])),
        sharedNotesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
        dueCountProvider.overrideWith((ref, uid) => Stream.value(0)),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: NotesHomeView(authUser: _user())),
    );

void main() {
  testWidgets('renders personalized header and note cards', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.textContaining('Maya'), findsWidgets);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('archive swipe shows undo toast', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    final card = find.text('Beta');
    await tester.drag(card, const Offset(-90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Note archived'), findsOneWidget);
  });
}
```

Note: the `initState` postFrame callback calls `shareServiceProvider.ensureUserProfile`, which touches Firestore. Wrap that call in `try/catch` inside `initState` (see Step 3) so the widget test does not crash with a MissingPluginException.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/notes_home_view_test.dart`
Expected: FAIL — NotesHomeView not yet rewritten (old SliverAppBar layout, no "Your notes" text).

- [ ] **Step 3: Rewrite notes_home_view.dart**

Full replacement. Public class keeps `NotesHomeView({super.key, required this.authUser})`. Implementation:

```dart
// lib/features/notes/presentation/notes_home_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/lock/presentation/lock_screen.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';
import 'package:mynotes/features/notes/presentation/note_editor_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/empty_state.dart';
import 'package:mynotes/features/notes/presentation/widgets/home_fab.dart';
import 'package:mynotes/features/notes/presentation/widgets/list_header.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_card.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_preview.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/account/presentation/account_sheet.dart';
import 'package:mynotes/features/account/presentation/archived_notes_view.dart';

class NotesHomeView extends ConsumerStatefulWidget {
  final AuthUser authUser;
  const NotesHomeView({super.key, required this.authUser});
  @override
  ConsumerState<NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends ConsumerState<NotesHomeView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _activeTag;
  String _filter = 'All';
  NoteSort _sort = NoteSort.updated;
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(shareServiceProvider).ensureUserProfile(
              uid: widget.authUser.uid,
              email: widget.authUser.email,
              displayName: widget.authUser.displayName,
            );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _userName() {
    final displayName = widget.authUser.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName.split(' ').first;
    final email = widget.authUser.email.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Writer';
  }

  String _timeLabel(DateTime updatedAt) {
    final difference = DateTime.now().difference(updatedAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';
  }

  Future<void> _openEditor({Note? note}) async {
    if (note != null && note.isLocked) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => LockScreen(noteId: note.id, pinHash: note.pinHash, pinSalt: note.pinSalt, child: NoteEditorView(authUser: widget.authUser, note: note))));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => NoteEditorView(authUser: widget.authUser, note: note)));
    }
  }

  Future<void> _togglePin(Note note) async {
    try {
      await ref.read(notesServiceProvider).togglePin(uid: widget.authUser.uid, note: note);
    } catch (_) {}
  }

  Future<void> _archive(Note note) async {
    try {
      await ref.read(notesServiceProvider).setArchived(uid: widget.authUser.uid, note: note, archived: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not archive note')));
      return;
    }
    showArchiveToast(context, () async {
      try {
        await ref.read(notesServiceProvider).setArchived(uid: widget.authUser.uid, note: note, archived: false);
      } catch (_) {}
    });
  }

  Future<void> _bulkArchive() async {
    final notes = _selectedNotes();
    try {
      await ref.read(notesServiceProvider).archiveMany(uid: widget.authUser.uid, notes: notes);
    } catch (_) {}
    setState(() { _selected.clear(); _selectMode = false; });
  }

  Future<void> _bulkDelete() async {
    final notes = _selectedNotes();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ${notes.length} note${notes.length == 1 ? '' : 's'}?'),
        content: const Text('This removes them permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(notesServiceProvider).deleteMany(uid: widget.authUser.uid, notes: notes);
    } catch (_) {}
    if (mounted) setState(() { _selected.clear(); _selectMode = false; });
  }

  Future<void> _bulkPin() async {
    final notes = _selectedNotes();
    final target = !notes.every((n) => n.isPinned);
    try {
      await ref.read(notesServiceProvider).setPinnedMany(uid: widget.authUser.uid, notes: notes, pinned: target);
    } catch (_) {}
    if (mounted) setState(() { _selected.clear(); _selectMode = false; });
  }

  List<Note> _selectedNotes() {
    final all = _mergedNotes();
    return all.where((n) => _selected.contains(n.id)).toList();
  }

  List<Note> _mergedNotes() {
    final own = ref.read(notesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    final shared = ref.read(sharedNotesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    return [...own, ...shared.where((n) => n.sharedBy != widget.authUser.uid)];
  }

  List<Note> _visible(List<Note> notes) {
    var list = notes.where((n) => !n.isArchived).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((n) =>
        n.title?.toLowerCase().contains(q) == true ||
        n.content?.toLowerCase().contains(q) == true ||
        (n.tags ?? const <String>[]).any((t) => t.toLowerCase().contains(q))).toList();
    }
    if (_activeTag != null) {
      list = list.where((n) => (n.tags ?? const <String>[]).contains(_activeTag)).toList();
    }
    if (_filter == 'Pinned') {
      list = list.where((n) => n.isPinned).toList();
    } else if (_filter == 'Recent') {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      list = list.where((n) => n.updatedAt.isAfter(cutoff)).toList();
    }
    final comparator = noteComparator(_sort);
    list.sort(comparator);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final notes = _mergedNotes();
    final visible = _visible(notes);
    final pinned = visible.where((n) => n.isPinned).toList();
    final rest = visible.where((n) => !n.isPinned).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: ListHeader(
                      userName: _userName(),
                      noteCount: notes.where((n) => !n.isArchived).length,
                      onOpenAccount: _openAccount,
                      onToggleSelect: () => setState(() { _selectMode = !_selectMode; _selected.clear(); }),
                      selectMode: _selectMode,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: NoteSearchField(controller: _searchController, onChanged: (v) => setState(() => _query = v.trim())),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FilterChips(active: _filter, pinnedCount: notes.where((n) => n.isPinned && !n.isArchived).length, onChanged: (v) => setState(() => _filter = v)),
                        SortMenu(sort: _sort, onChanged: (v) => setState(() => _sort = v)),
                      ],
                    ),
                  ),
                ),
                if (_activeTag != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(child: _FocusBar(tag: _activeTag!, onClear: () => setState(() => _activeTag = null))),
                  ),
                if (_selectMode)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(child: _SelectionBar(count: _selected.length, onPin: _bulkPin, onArchive: _bulkArchive, onDelete: _bulkDelete)),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(query: _query, activeTag: _activeTag, onCreate: () => _openEditor()),
                  )
                else ...[
                  if (pinned.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverToBoxAdapter(child: _SectionHeader(label: 'Pinned', count: pinned.length, pinned: true)),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: pinned.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCard(pinned[index], notes),
                    ),
                  ),
                  if (rest.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      sliver: SliverToBoxAdapter(child: _SectionHeader(label: 'All notes', count: rest.length, pinned: false)),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList.separated(
                      itemCount: rest.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCard(rest[index], notes),
                    ),
                  ),
                ],
              ],
            ),
            if (!_selectMode) HomeFab(onPressed: () => _openEditor()),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Note note, List<Note> allNotes) {
    return NoteCard(
      note: note,
      selectMode: _selectMode,
      selected: _selected.contains(note.id),
      onSelect: () => setState(() {
        if (_selected.contains(note.id)) { _selected.remove(note.id); } else { _selected.add(note.id); }
      }),
      onPin: () => _togglePin(note),
      onArchive: () => _archive(note),
      onOpen: () => _openEditor(note: note),
      onTagTap: (tag) => setState(() => _activeTag = tag),
      relativeTime: _timeLabel(note.updatedAt),
    );
  }

  void _openAccount() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => const AccountSheet());
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool pinned;
  const _SectionHeader({required this.label, required this.count, required this.pinned});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Row(children: [
      if (pinned) Icon(Icons.push_pin, size: 12, color: notely.violet),
      if (pinned) const SizedBox(width: 7),
      Text(label.toUpperCase(), style: TextStyle(fontFamily: 'Geist', fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: notely.text3)),
      const SizedBox(width: 6),
      Text('$count', style: TextStyle(fontSize: 11.5, color: notely.text4)),
      const SizedBox(width: 4),
      Expanded(child: Container(height: 1, color: notely.border)),
    ]);
  }
}

class _FocusBar extends StatelessWidget {
  final String tag;
  final VoidCallback onClear;
  const _FocusBar({required this.tag, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: notely.violetSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: notely.violetSoft2)),
      child: Row(children: [
        Icon(Icons.sell_outlined, size: 16, color: notely.violetInk),
        const SizedBox(width: 8),
        Expanded(child: Text('Focus: $tag', style: TextStyle(fontWeight: FontWeight.w700, color: notely.violetInk))),
        InkWell(onTap: onClear, customBorder: const CircleBorder(), child: Icon(Icons.close, size: 16, color: notely.violetInk)),
      ]),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  const _SelectionBar({required this.count, required this.onPin, required this.onArchive, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: notely.violetSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: notely.violetSoft2)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$count selected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: notely.violetInk)),
        Row(children: [
          _SmallAction(icon: Icons.push_pin_outlined, label: 'Pin', onTap: onPin),
          _SmallAction(icon: Icons.archive_outlined, label: 'Archive', onTap: onArchive),
          _SmallAction(icon: Icons.delete_outline, label: 'Delete', onTap: onDelete, danger: true),
        ]),
      ]),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _SmallAction({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: danger ? const Color(0xFFB91C1C) : notely.violetInk),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: danger ? const Color(0xFFB91C1C) : notely.violetInk)),
      ]),
    ));
  }
}
```

Note: `account_sheet.dart` and `archived_notes_view.dart` are created in Tasks 11 and 12; this task imports them. To keep this task compilable, create minimal stubs first in Task 10 (a placeholder `AccountSheet` returning `NotelySheet(child: Text('Account'))`) — but the plan puts real implementation in Task 11. **Do Task 11's account sheet file creation immediately after this task** before running `flutter analyze` on the full project, OR create empty class stubs in this task and fill them in Task 11. Recommend: create the two files with the real content in the next two tasks and run `flutter test` per-task only on this file's test. If you need the project to analyze cleanly mid-task, add temporary stubs:

```dart
// lib/features/account/presentation/account_sheet.dart (stub — replaced in Task 11)
import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});
  @override
  Widget build(BuildContext context) => const NotelySheet(child: Text('Account'));
}
```

```dart
// lib/features/account/presentation/archived_notes_view.dart (stub — replaced in Task 12)
import 'package:flutter/material.dart';

class ArchivedNotesView extends StatelessWidget {
  const ArchivedNotesView({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Archived')));
}
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/notes/presentation/notes_home_view_test.dart`
Expected: PASS. (If `buildNotePreview` isn't used in the card — the NoteCard renders `note.previewText` directly; the wiki-link preview is handled by `note_preview.dart` which Task 10 does not yet wire into NoteCard. To honor the spec (wiki links tappable), wire it: modify `NoteCard` to accept an optional `Widget? preview` and use it when provided. Update Task 8's NoteCard: add `final Widget? preview;` and render `preview ?? Text(note.previewText, ...)`. Do this small edit now and pass `buildNotePreview(context, note, allNotes, _openEditor)` from the home view's `_buildCard`.)

- [ ] **Step 5: Wire the wiki-link preview**

Edit `note_card.dart` (Task 8): add field `final Widget? preview;`, add to constructor `this.preview,`, and replace the direct preview `Text` with:

```dart
widget.preview ??
    Text(note.previewText, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.25, height: 1.45, letterSpacing: -0.15, color: notely.text3)),
```

In `notes_home_view.dart` `_buildCard`, pass `preview: buildNotePreview(context, note, allNotes, (n) => _openEditor(note: n))`.

Re-run `flutter test test/features/notes/presentation/note_card_test.dart` and `flutter test test/features/notes/presentation/notes_home_view_test.dart` — both must pass.

- [ ] **Step 6: Run full suite + analyzer**

Run: `flutter test` and `flutter analyze`
Expected: green. Note `test/features/notes/search/search_test.dart` and others must still pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/presentation/notes_home_view.dart lib/features/notes/presentation/widgets/note_card.dart lib/features/notes/presentation/widgets/note_preview.dart test/features/notes/presentation/notes_home_view_test.dart
git commit -m "feat: rebuild notes home view with Notely editorial design"
```

---

### Task 11: Account sheet

**Files:**
- Create: `lib/features/account/presentation/account_sheet.dart`
- Test: `test/features/account/presentation/account_sheet_test.dart`

**Interfaces:**
- Consumes: `NotelyTheme`, `NotelySheet`, `NotelyAvatar`, `themeModeProvider` (Task 3), `dueCountProvider`, `notesProvider`/`sharedNotesProvider`, `authServiceProvider`, `AuthUser`.
- Produces: `class AccountSheet extends ConsumerWidget` (takes `const AccountSheet({super.key, this.onNavigate})`). Rows: Appearance (cycles Light/Dark/System), Study cards (due count), Archive (archived count), Sign out. Pushes `ReviewView` and `ArchivedNotesView`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/account/presentation/account_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/account/presentation/account_sheet.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';

AuthUser _user() => const AuthUser(uid: 'u1', email: 'maya@example.com', displayName: 'Maya', isEmailVerified: true);

Note _n(String id, {bool archived = false}) => Note(
      id: id, title: 'T$id', content: 'c', colorIndex: 0, isPinned: false,
      isArchived: archived, createdAt: DateTime(2024, 1, 1), updatedAt: DateTime(2024, 1, 1));

Widget _wrap() => ProviderScope(
      overrides: [
        notesProvider.overrideWith((ref, uid) => Stream.value([_n('a'), _n('b', archived: true)])),
        sharedNotesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
        dueCountProvider.overrideWith((ref, uid) => Stream.value(2)),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: const Scaffold(body: AccountSheet())),
    );

void main() {
  testWidgets('shows profile, sync, and menu rows', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Synced to Firestore'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Study cards'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('appearance row toggles theme mode', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/account/presentation/account_sheet_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the account sheet**

```dart
// lib/features/account/presentation/account_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_avatar.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
import 'package:mynotes/features/account/presentation/archived_notes_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/presentation/review_view.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';

class AccountSheet extends ConsumerWidget {
  final AuthUser? authUser;
  const AccountSheet({super.key, this.authUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final due = ref.watch(dueCountProvider(_uid(ref))).valueOrNull ?? 0;
    final archivedCount = ref.watch(notesProvider(_uid(ref))).valueOrNull?.where((n) => n.isArchived).length ?? 0;
    final user = authUser ?? _currentUser(ref);

    String appearanceLabel() => switch (themeMode) {
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
          ThemeMode.system => 'System',
        };

    return NotelySheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              NotelyAvatar(size: 48, initial: _initialOf(user)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName?.isNotEmpty == true ? user.displayName! : user.email.split('@').first, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: notely.text)),
                    const SizedBox(height: 1),
                    Text(user.email, style: TextStyle(fontSize: 13, color: notely.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: notely.surface2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.cloud_done_outlined, size: 15, color: const Color(0xFF059669)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Synced to Firestore', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: notely.text)),
                  const SizedBox(height: 1),
                  Text('Last sync · just now', style: TextStyle(fontSize: 11.5, color: notely.text3)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _SheetRow(
            icon: Icons.brightness_6_outlined,
            label: 'Appearance',
            detail: appearanceLabel(),
            onTap: () {
              final next = themeMode == ThemeMode.light ? ThemeMode.dark : (themeMode == ThemeMode.dark ? ThemeMode.system : ThemeMode.light);
              ref.read(themeModeProvider.notifier).set(next);
            },
          ),
          _SheetRow(
            icon: Icons.school_outlined,
            label: 'Study cards',
            detail: '$due',
            onTap: () => _push(context, (c) => ReviewView(authUser: user)),
          ),
          _SheetRow(
            icon: Icons.archive_outlined,
            label: 'Archive',
            detail: '$archivedCount',
            onTap: () => _push(context, (c) => const ArchivedNotesView()),
          ),
          _SheetRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(authServiceProvider).logOut();
            },
          ),
        ],
      ),
    );
  }

  String _uid(WidgetRef ref) {
    final u = _currentUser(ref);
    return u.uid;
  }

  AuthUser _currentUser(WidgetRef ref) {
    final cached = ref.read(authStateProvider).valueOrNull;
    return cached ?? const AuthUser(uid: '', email: '', isEmailVerified: false);
  }

  String _initialOf(AuthUser user) {
    final name = user.displayName?.isNotEmpty == true ? user.displayName!.split(' ').first : user.email.split('@').first;
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }

  void _push(BuildContext context, Widget Function(BuildContext) builder) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final bool danger;

  const _SheetRow({required this.icon, required this.label, this.detail, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: notely.border))),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: danger ? const Color(0xFFDC2626).withValues(alpha: 0.1) : notely.violetSoft, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: danger ? const Color(0xFFDC2626) : notely.violetInk),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: danger ? const Color(0xFFDC2626) : notely.text))),
          if (detail != null) Text(detail!, style: TextStyle(fontSize: 13, color: notely.text3)),
          Icon(Icons.chevron_right, size: 14, color: notely.text4),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/account/presentation/account_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/account/presentation/account_sheet.dart test/features/account/presentation/account_sheet_test.dart
git commit -m "feat: add Notely account sheet with theme, study, archive, and sign out"
```

---

### Task 12: Archived notes view

**Files:**
- Create: `lib/features/account/presentation/archived_notes_view.dart`
- Test: `test/features/account/presentation/archived_notes_view_test.dart`

**Interfaces:**
- Consumes: `notesProvider`, `sharedNotesProvider`, `NotesService`, `NotelyTheme`, `Note`.
- Produces: `class ArchivedNotesView extends ConsumerWidget` with `const ArchivedNotesView({super.key, this.authUser})` — lists `isArchived == true` notes; tap row → `setArchived(false)` (unarchive); delete icon → `deleteNote` with confirm.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/account/presentation/archived_notes_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/account/presentation/archived_notes_view.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

AuthUser _user() => const AuthUser(uid: 'u1', email: 'maya@example.com', displayName: 'Maya', isEmailVerified: true);

Note _n(String id, {bool archived = false}) => Note(
      id: id, title: 'Title $id', content: 'c', colorIndex: 0, isPinned: false,
      isArchived: archived, createdAt: DateTime(2024, 1, 1), updatedAt: DateTime(2024, 1, 1));

Widget _wrap() => ProviderScope(
      overrides: [
        notesProvider.overrideWith((ref, uid) => Stream.value([_n('a', archived: true), _n('b')])),
        sharedNotesProvider.overrideWith((ref, uid) => Stream.value(const <Note>[])),
      ],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: ArchivedNotesView(authUser: _user())),
    );

void main() {
  testWidgets('lists only archived notes', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Title b'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/account/presentation/archived_notes_view_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the view**

```dart
// lib/features/account/presentation/archived_notes_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

class ArchivedNotesView extends ConsumerWidget {
  final AuthUser? authUser;
  const ArchivedNotesView({super.key, this.authUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final uid = authUser?.uid ?? ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final own = ref.watch(notesProvider(uid)).valueOrNull ?? const <Note>[];
    final shared = ref.watch(sharedNotesProvider(uid)).valueOrNull ?? const <Note>[];
    final archived = [...own, ...shared].where((n) => n.isArchived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: archived.isEmpty
          ? Center(child: Text('No archived notes', style: TextStyle(color: notely.text3)))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: archived.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = archived[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: notely.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: notely.border)),
                  child: Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            await ref.read(notesServiceProvider).setArchived(uid: uid, note: note, archived: false);
                          } catch (_) {}
                        },
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          const SizedBox(height: 2),
                          Text('Tap to restore', style: TextStyle(fontSize: 12, color: notely.text3)),
                        ]),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete forever',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete forever?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await ref.read(notesServiceProvider).deleteNote(uid: uid, noteId: note.id);
                          } catch (_) {}
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
```

Note: `authStateProvider` import comes from `features/auth/providers/auth_providers.dart`. Add it.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/account/presentation/archived_notes_view_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full suite + analyzer**

Run: `flutter test` and `flutter analyze`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add lib/features/account/presentation/archived_notes_view.dart test/features/account/presentation/archived_notes_view_test.dart
git commit -m "feat: add archived notes view with restore and delete"
```

---

### Task 13: Editor restyle

**Files:**
- Modify: `lib/features/notes/presentation/note_editor_view.dart`

**Interfaces:**
- Consumes: `NotelyTheme`, `TagPill`, `NotelySheet`.
- Produces: same public API (`NoteEditorView({super.key, required this.authUser, this.note})`). Behavior unchanged.

- [ ] **Step 1: Add imports**

At the top of `note_editor_view.dart` add:

```dart
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
import 'package:mynotes/core/theme/note_palette.dart';
```

- [ ] **Step 2: Replace the palette**

Delete the private `_palette` field (lines 55–62) and reference `kNotePalette` instead. Replace `_palette` uses: line 756 (`final accent = _palette[_selectedColorIndex % _palette.length];`), line 976 (`List.generate(_palette.length, ...)`), and any `_palette[bl.colorIndex % _palette.length]` (line 1232) with `kNotePalette`.

- [ ] **Step 3: Replace hardcoded colors with tokens**

In `build`, replace:
- Body `Container` gradient (lines 834–844) with a plain `Container(color: NotelyTheme.of(context).bg)`.
- `Color(0xFF141B2D)` container (line 854) → `NotelyTheme.of(context).surface`, border `accent.withValues(alpha: 0.25)` → `NotelyTheme.of(context).border`.
- `Colors.white70` / `Colors.white54` / `Colors.white60` / `Colors.white38` text colors → `NotelyTheme.of(context).text2` / `text3` / `text4`.
- The title TextField style (line 893) → `fontFamily: 'Instrument Serif', fontSize: 30, height: 1.1, letterSpacing: -0.6` (compose-sheet look); hintText 'Note title' stays.
- Content TextField (line 912) hint 'Write your note here...' → keep text, style stays Geist via `textTheme.bodyMedium`.
- Save `FilledButton` (line 1158) → `backgroundColor: notely.violet, foregroundColor: Colors.white`, radius 14 (already 18 → 14 is fine to keep at 18; keep 18 to match cards).

- [ ] **Step 4: Replace tags UI with TagPill**

- In the Tags section (line 1034 `_tags.map(... InputChip ...)`), replace `InputChip` with a `Wrap` of `TagPill(name: tag, outlined: true)`.
- `_showTagsDialog` (line 557): keep the dialog logic (add new tag / select), but wrap the modal in `NotelySheet` and render `allTags` as `FilterChip`s inside — replace `AlertDialog` container with a `showModalBottomSheet` + `NotelySheet`.

- [ ] **Step 5: Replace sheet containers with NotelySheet**

- `_showOcrSheet` (line 175): replace the `Container` gradient body with `NotelySheet(child: Column(...))`.
- `_SelfDestructSheet` (line 1460): replace outer `Container` with `NotelySheet`.
- `_ShareSheet` (line 1694): replace outer `Container` with `NotelySheet`.
- Replace `Colors.white70` icons inside these sheets with `NotelyTheme.of(context).text2`.

- [ ] **Step 6: Remove old status colors**

The ChoiceChips (Pin/Study) keep their default theme styling (violet active via colorScheme). The comment/backlink sections: replace `Color(0xFF141B2D)` / `Color(0xFF1A2340)` backgrounds with `notely.surface` / `notely.surface2`, and borders `Color(0xFF27314A)` with `notely.border`.

- [ ] **Step 7: Verify**

Run: `flutter analyze` — must be clean (no unused `_palette`, no `import` warnings).
Run: `flutter test` — existing suite green.

- [ ] **Step 8: Commit**

```bash
git add lib/features/notes/presentation/note_editor_view.dart
git commit -m "style: restyle note editor with Notely design language"
```

---

### Task 14: Secondary screens restyle (auth, lock, study, version history) + delete legacy widgets

**Files:**
- Modify: `lib/features/auth/presentation/login_view.dart`
- Modify: `lib/features/auth/presentation/register_view.dart`
- Modify: `lib/features/auth/presentation/verify_email_view.dart`
- Modify: `lib/features/lock/presentation/lock_screen.dart`
- Modify: `lib/features/study/presentation/review_view.dart`
- Modify: `lib/features/notes/presentation/version_history_view.dart`
- Delete: `lib/features/settings/presentation/widgets/theme_toggle_button.dart`
- Delete: `lib/features/notes/presentation/widgets/tag_chip.dart`
- Delete: `lib/features/notes/presentation/widgets/info_chip.dart`
- Delete: `lib/features/notes/presentation/widgets/empty_notes_state.dart` (replaced by `empty_state.dart`)
- Modify: `test/widget_test.dart` (final copy)
- Test: run full suite.

**Interfaces:**
- Consumes: `NotelyTheme`, `NotelyWordmark`, `TagPill`, `buildNotelyTheme`.

- [ ] **Step 1: Restyle login_view.dart**

- Remove `import '.../theme_toggle_button.dart';` and the `actions: const [ThemeToggleButton()]` from the AppBar.
- Replace the centered 'Note Log' text (lines 153–160) with:

```dart
const NotelyWordmark(size: 28),
```

- Replace the tagline (lines 162–167) with:
```dart
Text('Your private notes workspace', style: TextStyle(fontSize: 16, color: notely.text3)),
```
- `final notely = NotelyTheme.of(context);` at top of build; replace `Colors.grey` divider colors with `notely.border`; keep all controllers/logic/validation unchanged.
- Keep the Google `SignInButton`.

- [ ] **Step 2: Restyle register_view.dart**

- Remove ThemeToggleButton import + action.
- AppBar title 'Create account' → keep; inputs keep radius 10 → set to 14 via `borderRadius: BorderRadius.circular(14)`.
- Replace 'Note Log' branding if present (none in register; skip). Keep logic.

- [ ] **Step 3: Restyle verify_email_view.dart**

- Remove ThemeToggleButton import + action.
- Replace 'Welcome to Note Log!' (line 102) with 'Welcome to Notely!'.
- Icon `Icons.mark_email_unread_outlined` keep; use `NotelyTheme.of(context).violet` for icon color instead of green? Design has no green accent for verify; keep green (semantic success). Keep green.

- [ ] **Step 4: Restyle lock_screen.dart**

- Replace the Scaffold AppBar title 'Locked Note' styling: keep title text; set body to `NotelyTheme.of(context).bg`.
- Replace hardcoded icon/text/button with: serif heading 'This note is locked' styled `fontFamily: 'Instrument Serif', fontSize: 28`, lock icon in violet, biometric button → `FilledButton.icon` with `backgroundColor: notely.violet`. Keep `_canAttempt`, `_authenticate`, `_verifyPin` logic identical.
- PIN `TextField` keeps `outlineInputBorder`; cooldown text keeps red-ish.

- [ ] **Step 5: Restyle review_view.dart**

- Replace `Color(0xFF141B2D)` card (line 111) → `notely.surface`; border `Color(0xFF27314A)` → `notely.border`; progress `backgroundColor: Color(0xFF27314A)` → `notely.surface2`, `valueColor: notely.violet`.
- Question/Answer accent colors `Color(0xFF8AA7FF)`/`Color(0xFF86E7C8)` → `notely.violet` / `notely.success`.
- `Colors.white38`/`white60`/`white70` → `notely.text4`/`text3`/`text2`.
- `_RatingButton`: keep colors but ensure text uses Geist; `borderRadius: BorderRadius.circular(14)`.
- 'All caught up!' empty state: `Colors.white38` icon → `notely.text4`.

- [ ] **Step 6: Restyle version_history_view.dart**

- `Colors.white54`/`white70` text → `notely.text3`/`text2`; `colorScheme.primary` accents → `notely.violet`; Card stays (theme applies surface).
- Empty 'No versions yet' `Colors.white54` → `notely.text3`.

- [ ] **Step 7: Delete legacy widgets**

Delete files: `theme_toggle_button.dart`, `tag_chip.dart`, `info_chip.dart`, `empty_notes_state.dart`. Then grep for remaining imports:

```powershell
rg "theme_toggle_button|tag_chip|info_chip|empty_notes_state|AppThemeScope|ThemeToggleButton|InfoChip|EmptyNotesState" lib test
```

Fix any remaining references. `notes_home_view.dart` no longer imports these (rewritten in Task 10).

- [ ] **Step 8: Update widget_test.dart**

The login screen now shows the Notely wordmark (no 'Note Log' text). Update assertions:

```dart
expect(find.text('Notely'), findsOneWidget);
expect(find.byType(Scaffold), findsWidgets);
```

Remove the stale `'Dark notes workspace for ideas and drafts'` assertion.

- [ ] **Step 9: Run full suite + analyzer**

Run: `flutter test` and `flutter analyze`
Expected: green.

- [ ] **Step 10: Commit**

```bash
git add -A lib/features test/widget_test.dart
git commit -m "style: restyle auth, lock, study, and version history screens; remove legacy widgets"
```

---

### Task 15: Final verification

**Files:** none.

- [ ] **Step 1: Full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 2: Analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 3: Manual smoke test**

Run: `flutter run -d windows` (or Android emulator). Verify:
1. Login screen shows Notely wordmark + violet button.
2. Home shows "Your notes, {name}." serif title; search filters; Pinned/Recent chips; sort menu works.
3. Swipe a card left → Archive → undo toast restores it.
4. Select-mode: check icon → multi-select bar → Pin/Archive/Delete work.
5. Avatar → account sheet: Appearance toggles light/dark/system (persists across restart); Study cards opens ReviewView; Archive opens archived view; Sign out works.
6. Editor: title in Instrument Serif; tag pills; save button violet; sheets (OCR/share/self-destruct/tags) styled.
7. Locked note → lock screen styled; unlock works.
8. Version history + study review styled.

- [ ] **Step 4: Commit any manual fixes**

If the smoke test surfaces issues, fix them (TDD: add a failing test first if the fix is logic, else fix styling) and commit with `fix:` or `style:` prefix.

---

## Self-Review (completed by plan author)

**1. Spec coverage:**
- §1 design system → Tasks 1–4
- §2 data layer (isArchived, batch, sort, palette hoist) → Tasks 5–6 (palette hoist folded into Task 2)
- §3 notes list (header, search, chips, sort, sections, cards, swipe-archive, multi-select, FAB, empty state, status icons, preserved plumbing) → Tasks 7–10
- §4 account sheet + archived view → Tasks 11–12
- §5 editor restyle → Task 13
- §6 secondary screens + delete legacy → Task 14
- §7 error handling + tests → folded into each task; Task 15 final gate
- Rebrand Notely → Tasks 2, 3, 10, 13, 14
- Theme-mode fix (remove no-op toggle) → Task 3

**2. Placeholder scan:** No TBD/TODO. Every code step has concrete code. Restyle steps list exact lines + token substitutions.

**3. Type consistency:** `NotelyTheme.of`, `buildNotelyTheme`, `TagColors.resolve`, `noteComparator`, `Note.isArchived`, `setArchived/archiveMany/deleteMany/setPinnedMany`, `ListHeader/NoteSearchField/FilterChips/SortMenu`, `NoteCard(preview: ...)`, `HomeFab/EmptyState/buildNotePreview/showArchiveToast`, `AccountSheet/ArchivedNotesView`, `ThemeModeNotifier.set` — all names used identically across tasks.

## Execution Handoff

Plan complete. Two execution options:
1. **Subagent-Driven (recommended)** — fresh subagent per task + two-stage review.
2. **Inline Execution** — execute in this session with checkpoints.

Which approach do you want?
