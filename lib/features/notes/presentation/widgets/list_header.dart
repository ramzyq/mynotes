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
                          Flexible(
                            child: Text(
                              _labelFor(sort),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: notely.text),
                            ),
                          ),
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
