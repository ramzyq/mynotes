import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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
                GlassIconButton(
                  icon: Icon(selectMode ? Icons.close : Icons.check),
                  onPressed: onToggleSelect,
                  size: 34,
                  iconSize: 18,
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
              '$noteCount notes · synced',
              style: TextStyle(fontSize: 13, color: notely.text3, letterSpacing: -0.1),
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
    final hasText = controller.text.isNotEmpty;
    return GlassTextField.search(
      controller: controller,
      onChanged: onChanged,
      placeholder: 'Search notes, tags, content…',
      textStyle: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text),
      placeholderStyle: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text3),
      suffixIcon: hasText ? Icon(Icons.close, size: 16, color: notely.text3) : null,
      onSuffixTap: hasText
          ? () {
              controller.clear();
              onChanged('');
            }
          : null,
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
    Widget chip(String label) {
      final isActive = active == label;
      return GlassChip(
        label: label,
        selected: isActive,
        selectedColor: notely.violet,
        onTap: () => onChanged(label),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: TextStyle(
          fontFamily: 'Geist',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          color: isActive ? Colors.white : notely.text2,
        ),
      );
    }

    return Row(
      children: [
        chip('All'),
        const SizedBox(width: 6),
        GlassChip(
          label: pinnedCount > 0 ? 'Pinned · $pinnedCount' : 'Pinned',
          selected: active == 'Pinned',
          selectedColor: notely.violet,
          onTap: () => onChanged('Pinned'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          labelStyle: TextStyle(
            fontFamily: 'Geist',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            color: active == 'Pinned' ? Colors.white : notely.text2,
          ),
        ),
        const SizedBox(width: 6),
        chip('Recent'),
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
        NoteSort.titleAZ => 'Title (A–Z)',
        NoteSort.tag => 'Tag',
      };

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return GlassMenu(
      menuWidth: 180,
      triggerBuilder: (context, toggleMenu) => GlassChip(
        label: _labelFor(sort),
        icon: Icon(Icons.swap_vert, size: 14, color: notely.text2),
        onTap: toggleMenu,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500, color: notely.text2),
      ),
      items: [
        for (final option in NoteSort.values)
          GlassMenuItem(
            title: _labelFor(option),
            isSelected: sort == option,
            titleStyle: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text),
            onTap: () => onChanged(option),
          ),
      ],
    );
  }
}
