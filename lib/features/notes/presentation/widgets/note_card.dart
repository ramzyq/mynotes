// lib/features/notes/presentation/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';
import 'package:mynotes/features/notes/data/note.dart';

/// The margin line: a thin rule in the note's color label down the left
/// edge, like the margin of ruled paper. Used on cards and in the editor.
class NoteMarginLine extends StatelessWidget {
  final Color color;
  const NoteMarginLine({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 2,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
      );
}

class NoteCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final margin = kNotePalette[note.colorIndex % kNotePalette.length];
    final checklist = note.checklist;
    final metaIcons = <IconData>[
      if (note.reminderAt != null && note.reminderAt!.isAfter(DateTime.now())) Icons.notifications_none,
      if (note.isLocked) Icons.lock_outline,
      if (note.selfDestructAt != null) Icons.timer_outlined,
      if (note.selfDestructOnRead) Icons.visibility_off_outlined,
      if ((note.collaborators ?? const <String>[]).isNotEmpty) Icons.group_outlined,
    ];

    // Swipe left to reveal Archive. Slidable takes part in the gesture arena,
    // so vertical scrolling never drags the card sideways, and it animates
    // with a transform instead of rebuilding the card on every pointer move.
    return Slidable(
      key: ValueKey('swipe-${note.id}'),
      enabled: !selectMode,
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.32,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onArchive(),
            backgroundColor: notely.surface2,
            foregroundColor: notely.text,
            borderRadius: BorderRadius.circular(14),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.archive_outlined, size: 18),
                SizedBox(width: 8),
                Text('Archive', style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: Material(
          color: notely.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? notely.violet : notely.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selectMode ? onSelect : onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NoteMarginLine(color: margin),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (selectMode) ...[
                                _SelectDot(selected: selected),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
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
                              ),
                              const SizedBox(width: 8),
                              _PinButton(pinned: note.isPinned, onTap: onPin),
                            ],
                          ),
                          const SizedBox(height: 4),
                          preview ??
                              Text(
                                note.previewText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2),
                              ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (note.latitude != null && note.longitude != null) ...[
                                Icon(Icons.location_on_outlined, size: 14, color: notely.text3),
                                if (note.placeName != null) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    note.placeName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: notely.text3),
                                  ),
                                ),
                                ],
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    for (final tag in note.tags ?? const <String>[])
                                      GestureDetector(
                                        onTap: () => onTagTap(tag),
                                        child: TagPill(name: tag, style: TagPillStyle.dot),
                                      ),
                                  ],
                                ),
                              ),
                              if (checklist != null) ...[
                                Icon(Icons.checklist, size: 14, color: notely.text3),
                                const SizedBox(width: 4),
                                Text(
                                  '${checklist.done}/${checklist.total}',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12,
                                    color: notely.text3,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              for (final icon in metaIcons) ...[
                                Icon(icon, size: 14, color: notely.text3),
                                const SizedBox(width: 6),
                              ],
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinButton extends StatelessWidget {
  final bool pinned;
  final VoidCallback onTap;
  const _PinButton({required this.pinned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Tooltip(
      message: pinned ? 'Unpin' : 'Pin',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            pinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 16,
            color: pinned ? notely.text2 : notely.text4,
          ),
        ),
      ),
    );
  }
}

class _SelectDot extends StatelessWidget {
  final bool selected;
  const _SelectDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? notely.violet : Colors.transparent,
        border: Border.all(color: selected ? notely.violet : notely.borderStrong, width: 1.5),
      ),
      child: selected ? Icon(Icons.check, size: 12, color: notely.surface) : null,
    );
  }
}
