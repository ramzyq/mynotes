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
