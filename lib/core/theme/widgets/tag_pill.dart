import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/tag_colors.dart';

enum TagPillStyle { pill, dot, outlined }

/// A tag: neutral text with a small colored dot. The dot is the only place
/// the tag's color shows, so a card full of tags stays calm.
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
    final dot = TagColors.resolve(name, Theme.of(context).brightness).dot;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          name,
          style: TextStyle(fontFamily: 'Geist', fontSize: 12, height: 1.33, color: notely.text2),
        ),
      ],
    );

    if (style == TagPillStyle.dot) return label;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: style == TagPillStyle.outlined ? Colors.transparent : notely.surface2,
        borderRadius: BorderRadius.circular(6),
        border: style == TagPillStyle.outlined ? Border.all(color: notely.border) : null,
      ),
      child: label,
    );
  }
}
