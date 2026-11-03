import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/tag_colors.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';

class TagsSheet extends StatefulWidget {
  final Set<String> allTags;
  final List<String> initialSelected;

  const TagsSheet({
    super.key,
    required this.allTags,
    required this.initialSelected,
  });

  @override
  State<TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<TagsSheet> {
  late final TextEditingController _controller = TextEditingController();
  late final Set<String> _allTags = Set<String>.of(widget.allTags);
  late final List<String> _selected = List<String>.of(widget.initialSelected);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addNewTag() {
    final tag = _controller.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_selected.contains(tag)) _selected.add(tag);
      _allTags.add(tag);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tags',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _addNewTag(),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'New tag'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addNewTag,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add tag',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_allTags.isEmpty)
              Text(
                'No tags yet. Type one above to create it.',
                style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text2),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allTags.map((tag) {
                  return FilterChip(
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: TagColors.resolve(tag, Theme.of(context).brightness).dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    showCheckmark: false,
                    label: Text(tag),
                    selected: _selected.contains(tag),
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          if (!_selected.contains(tag)) _selected.add(tag);
                        } else {
                          _selected.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            NotelyPrimaryButton(label: 'Save', onPressed: () => Navigator.of(context).pop(_selected)),
          ],
        ),
    );
  }
}
