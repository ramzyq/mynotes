import 'package:flutter/widgets.dart';

/// A note's place: its box and its tilt.
@immutable
class DeskSpot {
  const DeskSpot(this.rect, this.degrees);
  final Rect rect;
  final double degrees;

  static DeskSpot lerp(DeskSpot a, DeskSpot b, double t) =>
      DeskSpot(Rect.lerp(a.rect, b.rect, t)!, a.degrees + (b.degrees - a.degrees) * t);
}

/// The three notes on the sign-in screens: light blue at the back left, dark
/// blue at the back right, paper in the middle. These are the three notes of
/// the Notely logo, so [logo] gives each one's spot in the mark too.
enum DeskNoteRole { left, right, middle }

/// Where the notes sit on a screen of [size], below a top inset of [top].
class DeskLayout {
  DeskLayout(this.size, {required this.top});

  final Size size;
  final double top;

  /// Designed at 360 wide; grows a little on big phones, shrinks on small.
  double get scale => (size.width / 360).clamp(0.85, 1.3);

  DeskSpot desk(DeskNoteRole role) {
    final s = scale;
    return switch (role) {
      DeskNoteRole.left => DeskSpot(Rect.fromLTWH(-24 * s, top + 18 * s, 134 * s, 152 * s), -14),
      DeskNoteRole.right => DeskSpot(Rect.fromLTWH(size.width - 102 * s, top - 4 * s, 134 * s, 152 * s), 11),
      DeskNoteRole.middle => DeskSpot(
          Rect.fromCenter(center: Offset(size.width / 2, top + 168 * s), width: 114 * s, height: 124 * s),
          -4,
        ),
    };
  }

  /// The logo's size on the welcome moment.
  double get logoSize => 180 * scale;

  /// Top-left of the logo: centred, a little above the middle so the name
  /// fits underneath.
  Offset get logoOrigin => Offset((size.width - logoSize) / 2, size.height * 0.44 - logoSize * 0.75);

  /// Each note's spot inside the logo. From NotelyMarkPainter: a 512-unit
  /// drawing at (4, 8) in a 520-unit box.
  DeskSpot logo(DeskNoteRole role) {
    final k = logoSize / 520;
    Rect box(double cx, double cy, double w, double h) =>
        Rect.fromCenter(center: logoOrigin + Offset(cx * k, cy * k), width: w * k, height: h * k);
    return switch (role) {
      DeskNoteRole.left => DeskSpot(box(195, 308, 288, 288), -17.2),
      DeskNoteRole.right => DeskSpot(box(346.5, 349.5, 287, 287), 6),
      DeskNoteRole.middle => DeskSpot(box(274, 205.5, 290, 295), 0),
    };
  }

  /// The logo's outline width at its drawn size (22 units of 520).
  double get logoStroke => 22 * logoSize / 520;
}
