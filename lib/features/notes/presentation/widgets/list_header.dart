import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_avatar.dart';
import 'package:mynotes/core/theme/widgets/notely_wordmark.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';

class ListHeader extends StatelessWidget {
  final String userName;
  /// Null while the notes are still loading.
  final int? noteCount;
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
            const NotelyWordmark(size: 16),
            Row(
              children: [
                TextButton(
                  onPressed: onToggleSelect,
                  style: TextButton.styleFrom(
                    foregroundColor: notely.text2,
                    textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(selectMode ? 'Cancel' : 'Select'),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Account',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onOpenAccount,
                    child: NotelyAvatar(initial: userName),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.displayLarge,
            children: [
              const TextSpan(text: 'Your notes, '),
              TextSpan(
                text: '$userName.',
                style: TextStyle(fontStyle: FontStyle.italic, color: notely.violet),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // The privacy promise, stated where people look first. True for every
        // note: content is encrypted on this device before it is synced.
        Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: notely.text3),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                noteCount == null
                    ? 'Encrypted on this device'
                    : '$noteCount ${noteCount == 1 ? 'note' : 'notes'} · encrypted on this device',
                style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3),
              ),
            ),
          ],
        ),
      ],
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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontFamily: 'Geist', fontSize: 15, color: notely.text),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(fontFamily: 'Geist', fontSize: 15, color: notely.text3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            prefixIcon: Icon(Icons.search, size: 18, color: notely.text3),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.close, size: 16, color: notely.text3),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// A quiet filter chip: hairline when idle, ink tint when selected.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final fg = selected ? notely.violetInk : notely.text2;
    return Material(
      color: selected ? notely.violetSoft : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? notely.violetSoft2 : notely.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
            ],
          ),
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
    return Row(
      children: [
        _FilterChip(label: 'All', selected: active == 'All', onTap: () => onChanged('All')),
        const SizedBox(width: 8),
        _FilterChip(
          label: pinnedCount > 0 ? 'Pinned $pinnedCount' : 'Pinned',
          selected: active == 'Pinned',
          onTap: () => onChanged('Pinned'),
        ),
        const SizedBox(width: 8),
        _FilterChip(label: 'Recent', selected: active == 'Recent', onTap: () => onChanged('Recent')),
      ],
    );
  }
}

class SortMenu extends StatelessWidget {
  final NoteSort sort;
  final ValueChanged<NoteSort> onChanged;

  const SortMenu({super.key, required this.sort, required this.onChanged});

  String _labelFor(NoteSort sort) => switch (sort) {
        NoteSort.updated => 'Updated',
        NoteSort.created => 'Created',
        NoteSort.titleAZ => 'Title A–Z',
        NoteSort.tag => 'Tag',
      };

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(notely.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: notely.border),
        )),
      ),
      menuChildren: [
        for (final option in NoteSort.values)
          MenuItemButton(
            onPressed: () => onChanged(option),
            trailingIcon: sort == option ? Icon(Icons.check, size: 16, color: notely.violet) : null,
            child: SizedBox(
              width: 140,
              child: Text(_labelFor(option), style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text)),
            ),
          ),
      ],
      builder: (context, controller, _) => _FilterChip(
        label: _labelFor(sort),
        icon: Icons.swap_vert,
        selected: false,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
