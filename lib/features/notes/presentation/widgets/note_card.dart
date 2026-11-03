// lib/features/notes/presentation/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  final Widget? preview;

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
    this.preview,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final note = widget.note;

    // Swipe left to reveal Archive. Slidable takes part in the gesture arena,
    // so vertical scrolling never drags the card sideways, and it animates
    // with a transform instead of rebuilding the card on every pointer move.
    return Slidable(
      key: ValueKey('swipe-${note.id}'),
      enabled: !widget.selectMode,
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.32,
        children: [
          CustomSlidableAction(
            onPressed: (_) => widget.onArchive(),
            backgroundColor: const Color(0xFFFCA5A5),
            foregroundColor: const Color(0xFF7F1D1D),
            borderRadius: BorderRadius.circular(18),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.archive_outlined, size: 18),
                SizedBox(width: 6),
                Text(
                  'Archive',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: notely.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.selected ? notely.violet : notely.border,
              width: widget.selected ? 2 : 1,
            ),
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
                          color: widget.selected
                              ? notely.violet
                              : Colors.transparent,
                          border: Border.all(
                            color: widget.selected
                                ? notely.violet
                                : notely.borderStrong,
                            width: 1.5,
                          ),
                        ),
                        child: widget.selected
                            ? Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        note.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                          letterSpacing: -0.32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: widget.onPin,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          note.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 14,
                          color: note.isPinned ? notely.violet : notely.text4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                widget.preview ??
                    Text(
                      note.previewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13.25,
                        height: 1.45,
                        letterSpacing: -0.15,
                        color: notely.text3,
                      ),
                    ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (note.latitude != null && note.longitude != null) ...[
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: notely.text4,
                      ),
                      if (note.placeName != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            note.placeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 11.5,
                              color: notely.text3,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                    ],
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
                      Icon(
                        Icons.visibility_off_outlined,
                        size: 12,
                        color: notely.text4,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if ((note.collaborators ?? const <String>[])
                        .isNotEmpty) ...[
                      Icon(Icons.group_outlined, size: 12, color: notely.text4),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      widget.relativeTime,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: notely.text4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
