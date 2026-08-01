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

  void _onPointerUp(PointerEvent e) {
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
