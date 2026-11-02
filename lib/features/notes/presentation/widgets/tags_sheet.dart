import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tags',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
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
                    decoration: const InputDecoration(
                      hintText: 'New tag name',
                      prefixIcon: Icon(Icons.add),
                    ),
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
                'No tags yet. Create one above.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: notely.text3),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allTags.map((tag) {
                  return FilterChip(
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
    );
  }
}
