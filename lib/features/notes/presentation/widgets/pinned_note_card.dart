import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';
import 'package:mynotes/features/notes/data/note.dart';

/// A pinned note drawn as an index card: a header line, the colored rule an
/// index card has under its heading, then the note. The rule takes the
/// note's color label, so pinned notes read at a glance.
class PinnedNoteCard extends StatelessWidget {
  final Note note;
  final String relativeTime;
  final bool selectMode;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onSelect;
  final VoidCallback onUnpin;
  final VoidCallback onArchive;

  const PinnedNoteCard({
    super.key,
    required this.note,
    required this.relativeTime,
    this.selectMode = false,
    this.selected = false,
    required this.onOpen,
    required this.onSelect,
    required this.onUnpin,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tags = note.tags ?? const <String>[];
    final rule = kNotePalette[note.colorIndex % kNotePalette.length];

    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: dark
            ? null
            : const [BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Material(
        color: notely.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? notely.violet : notely.border, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selectMode ? onSelect : onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: tags.isEmpty
                            ? Text(
                                relativeTime,
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  color: notely.text3,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              )
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: TagPill(name: tags.first, style: TagPillStyle.dot),
                              ),
                      ),
                      if (selectMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? notely.violet : Colors.transparent,
                              border: Border.all(color: selected ? notely.violet : notely.borderStrong, width: 1.5),
                            ),
                            child: selected ? Icon(Icons.check, size: 12, color: notely.surface) : null,
                          ),
                        )
                      else
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (value) {
                            if (value == 'unpin') onUnpin();
                            if (value == 'archive') onArchive();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'unpin', child: Text('Unpin')),
                            PopupMenuItem(value: 'archive', child: Text('Archive')),
                          ],
                          icon: Icon(Icons.more_horiz, size: 18, color: notely.text3),
                        ),
                    ],
                  ),
                ),
              ),
              Container(height: 1.5, color: rule.withValues(alpha: dark ? 0.7 : 0.55)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.33,
                          color: notely.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          note.previewText,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2),
                        ),
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          relativeTime,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: notely.text3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
