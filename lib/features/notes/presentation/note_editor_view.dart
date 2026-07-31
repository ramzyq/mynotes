import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

class NoteEditorView extends ConsumerStatefulWidget {
  final AuthUser authUser;
  final Note? note;

  const NoteEditorView({
    super.key,
    required this.authUser,
    this.note,
  });

  @override
  ConsumerState<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends ConsumerState<NoteEditorView> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late int _selectedColorIndex;
  late bool _isPinned;
  bool _isSaving = false;
  bool _isDeleting = false;

  static const List<Color> _palette = [
    Color(0xFF86E7C8),
    Color(0xFF8AA7FF),
    Color(0xFFFFC46B),
    Color(0xFFFF8FA3),
    Color(0xFF9D93FF),
    Color(0xFF67D3FF),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedColorIndex = widget.note?.colorIndex ?? 0;
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (widget.note == null) {
        final note = await ref.read(notesServiceProvider).createNote(
          uid: widget.authUser.uid,
          title: title.isEmpty && content.isEmpty ? 'Untitled note' : title,
          content: content,
          colorIndex: _selectedColorIndex,
          isPinned: _isPinned,
        );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(note);
      } else {
        await ref.read(notesServiceProvider).updateNote(
          uid: widget.authUser.uid,
          note: widget.note!.copyWith(
            title: title.isEmpty && content.isEmpty ? 'Untitled note' : title,
            content: content,
            colorIndex: _selectedColorIndex,
            isPinned: _isPinned,
          ),
        );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteNote() async {
    final note = widget.note;
    if (note == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This removes the note permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await ref.read(notesServiceProvider).deleteNote(
        uid: widget.authUser.uid,
        noteId: note.id,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _toggleLock() async {
    final note = widget.note;
    if (note == null) return;

    final lockService = ref.read(lockServiceProvider);
    final canBio = await lockService.canUseBiometrics();

    if (!note.isLocked) {
      if (canBio) {
        // Lock with biometrics only
        await ref.read(notesServiceProvider).updateNote(
          uid: widget.authUser.uid,
          note: note.copyWith(isLocked: true),
        );
      } else {
        // No biometrics - prompt for PIN
        if (!mounted) return;
        final pinController = TextEditingController();
        final pin = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Set a PIN'),
            content: TextField(
              controller: pinController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Enter PIN',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(pinController.text),
                child: const Text('Set PIN'),
              ),
            ],
          ),
        );
        if (pin != null && pin.isNotEmpty) {
          final pinHash = await lockService.hashPin(pin);
          await ref.read(notesServiceProvider).updateNote(
            uid: widget.authUser.uid,
            note: note.copyWith(
              isLocked: true,
              pinHash: pinHash.hash,
              pinSalt: pinHash.salt,
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {});
    } else {
      // Unlock - clear lock
      await ref.read(notesServiceProvider).updateNote(
        uid: widget.authUser.uid,
        note: note.copyWith(
          isLocked: false,
          pinHash: null,
          pinSalt: null,
        ),
      );
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final accent = _palette[_selectedColorIndex % _palette.length];

    return Scaffold(
      appBar: AppBar(
        title: Text(note == null ? 'New note' : 'Edit note'),
        actions: [
          if (note != null)
            IconButton(
              icon: Icon(note.isLocked ? Icons.lock : Icons.lock_open),
              onPressed: _isSaving || _isDeleting ? null : _toggleLock,
            ),
          if (note != null)
            IconButton(
              onPressed: _isSaving || _isDeleting ? null : _deleteNote,
              icon: _isDeleting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0F1A),
              Color(0xFF0F1627),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141B2D),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(_isPinned ? 'Pinned' : 'Pin note'),
                            selected: _isPinned,
                            onSelected: (selected) {
                              setState(() => _isPinned = selected);
                            },
                          ),
                          const Spacer(),
                          Text(
                            note == null ? 'Draft' : 'Saved note',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _titleController,
                        enabled: !_isSaving,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        decoration: const InputDecoration(
                          hintText: 'Note title',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        enabled: !_isSaving,
                        minLines: 12,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Write your note here...',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Color label',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_palette.length, (index) {
                    final color = _palette[index];
                    final selected = _selectedColorIndex == index;
                    return GestureDetector(
                      onTap: _isSaving ? null : () => setState(() => _selectedColorIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.black)
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveNote,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(note == null ? 'Create note' : 'Save changes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
