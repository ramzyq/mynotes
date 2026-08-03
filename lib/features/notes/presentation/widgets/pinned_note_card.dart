import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/tag_colors.dart';
import 'package:mynotes/features/notes/data/note.dart';

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
    final brightness = Theme.of(context).brightness;
    final tags = note.tags ?? const <String>[];
    final tag = tags.isNotEmpty ? tags.first : null;

    final TagPalette palette;
    final Color accent;
    if (tag != null) {
      palette = TagColors.resolve(tag, brightness);
      accent = palette.dot;
    } else {
      palette = (fg: notely.text2, bg: notely.surface2, dot: notely.text3);
      accent = notely.text3;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selectMode ? onSelect : onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: notely.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? notely.violet : notely.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Pill(name: tag ?? 'General', fg: palette.fg, bg: palette.bg),
                          ),
                          if (selectMode)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? notely.violet : Colors.transparent,
                                border: Border.all(
                                  color: selected ? notely.violet : notely.borderStrong,
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? Icon(Icons.check, size: 12, color: Colors.white)
                                  : null,
                            )
                          else
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'unpin') onUnpin();
                                  if (value == 'archive') onArchive();
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'unpin', child: Text('Unpin')),
                                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                                ],
                                icon: Icon(Icons.more_vert, size: 18, color: notely.text3),
                                padding: EdgeInsets.zero,
                                splashRadius: 16,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        note.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          letterSpacing: -0.32,
                          color: notely.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.previewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          height: 1.45,
                          letterSpacing: -0.15,
                          color: notely.text3,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      Text(
                        relativeTime,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: notely.text4,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 4, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String name;
  final Color fg;
  final Color bg;

  const _Pill({required this.name, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg, height: 1.2),
      ),
    );
  }
}
