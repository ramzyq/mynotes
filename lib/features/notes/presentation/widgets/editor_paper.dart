import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

/// The editor drawn as a paper note, like the one in the Notely logo: a
/// sheet with the logo's clip in the note's colour, its top washed in that
/// colour, and the writing on faint ruled lines.

/// The paper's outline: the logo's ink in light mode, a warm grey in dark
/// mode so the edge still reads on the dark page.
Color paperOutline(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5E584F) : const Color(0xFF1F1B16);

/// The clip at the top of the sheet, in the note's colour. Tapping it
/// changes the colour.
class PaperClip extends StatelessWidget {
  const PaperClip({super.key, required this.color, this.onTap});
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Note colour',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // A bigger target than the clip itself.
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 22,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: paperOutline(context), width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

/// The wash at the top of the sheet: the note's colour, fading down. Light
/// paper needs a deeper wash for the colour to read.
Gradient paperHeaderWash(BuildContext context, Color color) {
  final light = Theme.of(context).brightness == Brightness.light;
  return LinearGradient(
    begin: const Alignment(-0.3, -1),
    end: const Alignment(0.3, 1),
    colors: light
        ? [color.withValues(alpha: 0.42), color.withValues(alpha: 0.16), color.withValues(alpha: 0.08)]
        : [color.withValues(alpha: 0.38), color.withValues(alpha: 0.10), color.withValues(alpha: 0.02)],
    stops: const [0, 0.85, 1],
  );
}

/// One badge in the sheet's header: colour, a tag, a reminder, the place...
/// Tap one to change it.
class PaperBadge extends StatelessWidget {
  const PaperBadge({
    super.key,
    required this.label,
    required this.tooltip,
    this.leading,
    this.onTap,
    this.color,
    this.dashed = false,
    this.shimmer = false,
  });

  final String label;
  final String tooltip;
  final Widget? leading;
  final VoidCallback? onTap;
  final Color? color;

  /// An empty slot ("Add tags").
  final bool dashed;

  /// Still working it out ("Finding you…").
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final fg = color ?? notely.text;
    Widget chip = Container(
      height: 28,
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: dashed ? Colors.transparent : notely.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dashed ? notely.borderStrong : notely.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Geist', fontSize: 12.5, color: dashed ? notely.text3 : fg),
            ),
          ),
        ],
      ),
    );
    if (shimmer) chip = _Shimmer(child: chip);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: chip),
      ),
    );
  }
}

/// A soft pulse while a badge is still loading.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Endless, so not under reduce motion or tests (it would never settle).
    NotelyMotion.ambient(context) ? _c.repeat(reverse: true) : _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: Tween(begin: 0.45, end: 1.0).animate(_c), child: widget.child);
  }
}

/// Faint ruled lines under the writing, one per line of text.
class RuledLinesPainter extends CustomPainter {
  RuledLinesPainter({required this.lineHeight, required this.color, this.top = 0});
  final double lineHeight;
  final Color color;
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = top + lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(RuledLinesPainter old) => old.lineHeight != lineHeight || old.color != color || old.top != top;
}

/// The note's place as a small map, clipped under the writing like a photo:
/// a slight tilt, the paper's outline, a pin in the note's colour.
class NoteMapCard extends StatelessWidget {
  const NoteMapCard({super.key, required this.latitude, required this.longitude, required this.color, this.placeName, this.onTap});

  final double latitude;
  final double longitude;
  final String? placeName;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Semantics(
      button: onTap != null,
      label: placeName == null ? 'Location' : 'Location: $placeName',
      child: GestureDetector(
        onTap: onTap,
        child: Transform.rotate(
          angle: -1.2 * math.pi / 180,
          child: Container(
            height: 136,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: paperOutline(context), width: 3),
              boxShadow: const [BoxShadow(color: Color(0x38000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  // A still picture of the place; the sheet has the map you can move.
                  IgnorePointer(child: NoteMap(latitude: latitude, longitude: longitude, color: color, zoom: 15)),
                  if (placeName != null)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: notely.surface.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(Icons.location_on, size: 14, color: color),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              placeName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Geist', fontSize: 12.5, color: notely.text),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An OpenStreetMap map with a pin in the note's colour.
class NoteMap extends StatelessWidget {
  const NoteMap({super.key, required this.latitude, required this.longitude, required this.color, this.zoom = 15, this.interactive = false});

  final double latitude;
  final double longitude;
  final Color color;
  final double zoom;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(flags: interactive ? InteractiveFlag.all : InteractiveFlag.none),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.flutter.mynotes'),
        MarkerLayer(markers: [
          Marker(
            point: point,
            width: 36,
            height: 36,
            alignment: Alignment.topCenter,
            child: Icon(Icons.location_on, color: color, size: 36, shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)]),
          ),
        ]),
      ],
    );
  }
}

/// One tool in the editor's bar: an icon with its name under it.
class EditorTool {
  const EditorTool({required this.icon, required this.label, required this.onTap, this.color, this.busy = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool busy;
}

/// The tool bar, docked on top of the keyboard (and at the bottom when the
/// keyboard is away): a solid rounded bar with labelled tools.
class EditorToolBar extends StatelessWidget {
  const EditorToolBar({super.key, required this.tools});
  final List<EditorTool> tools;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      height: 54,
      decoration: BoxDecoration(color: notely.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final tool in tools)
            Expanded(
              child: Semantics(
                button: true,
                label: tool.label,
                child: InkWell(
                  onTap: tool.busy ? null : tool.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Builder(builder: (context) {
                    final fg = tool.onTap == null && !tool.busy ? notely.text4 : (tool.color ?? notely.text2);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        tool.busy
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                            : Icon(tool.icon, size: 20, color: fg),
                        const SizedBox(height: 2),
                        ExcludeSemantics(
                          child: Text(tool.label, style: TextStyle(fontFamily: 'Geist', fontSize: 10.5, color: fg)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
