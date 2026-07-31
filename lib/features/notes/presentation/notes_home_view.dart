import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/lock/presentation/lock_screen.dart';
import 'package:mynotes/features/notes/presentation/note_editor_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/empty_notes_state.dart';
import 'package:mynotes/features/notes/presentation/widgets/info_chip.dart';
import 'package:mynotes/features/notes/presentation/widgets/tag_chip.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/settings/presentation/widgets/theme_toggle_button.dart';
import 'package:mynotes/features/study/presentation/review_view.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';

final _linkRegex = RegExp(r'\[\[([^\]]+)\]\]');

class NotesHomeView extends ConsumerStatefulWidget {
  final AuthUser authUser;

  const NotesHomeView({
    super.key,
    required this.authUser,
  });

  @override
  ConsumerState<NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends ConsumerState<NotesHomeView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _activeTag;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareServiceProvider).ensureUserProfile(
        uid: widget.authUser.uid,
        email: widget.authUser.email,
        displayName: widget.authUser.displayName,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _greetingName() {
    final displayName = widget.authUser.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }

    final email = widget.authUser.email.trim();
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Writer';
  }

  String _timeLabel(DateTime updatedAt) {
    final difference = DateTime.now().difference(updatedAt);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';
  }

  Future<void> _openEditor({Note? note}) async {
    if (note != null && note.isLocked) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LockScreen(
            noteId: note.id,
            pinHash: note.pinHash,
            pinSalt: note.pinSalt,
            child: NoteEditorView(
              authUser: widget.authUser,
              note: note,
            ),
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NoteEditorView(
            authUser: widget.authUser,
            note: note,
          ),
        ),
      );
    }
  }

  Future<void> _togglePin(Note note) async {
    await ref.read(notesServiceProvider).togglePin(uid: widget.authUser.uid, note: note);
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('Delete "${note.displayTitle}" permanently?'),
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

    if (confirmed == true) {
      await ref.read(notesServiceProvider).deleteNote(uid: widget.authUser.uid, noteId: note.id);
    }
  }

  Future<void> _showContextSwitcher(List<Note> notes) async {
    final tagCounts = <String, int>{};
    for (final note in notes) {
      for (final tag in (note.tags ?? const [])) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final sortedTags = tagCounts.keys.toList()..sort();

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141B2D), Color(0xFF0B0F1A)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list_rounded, color: Colors.white70),
                const SizedBox(width: 12),
                Text(
                  'Context switcher',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              selected: _activeTag == null,
              selectedTileColor: const Color(0xFF1A2340),
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: const Text('All Notes'),
              trailing: Text(
                '${notes.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white54,
                    ),
              ),
              onTap: () => Navigator.of(context).pop(''),
            ),
            if (sortedTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedTags.length,
                  itemBuilder: (context, index) {
                    final tag = sortedTags[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      selected: _activeTag == tag,
                      selectedTileColor: const Color(0xFF1A2340),
                      leading: const Icon(Icons.sell_outlined),
                      title: Text(tag),
                      trailing: Text(
                        '${tagCounts[tag]}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white54,
                            ),
                      ),
                      onTap: () => Navigator.of(context).pop(tag),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _activeTag = result.isEmpty ? null : result);
    }
  }

  Widget _buildLinkPreview(Note note, List<Note> allNotes) {
    final text = note.previewText;
    final matches = _linkRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(
        text,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.45,
            ),
      );
    }

    final existingTitles = allNotes.map((n) => n.title?.trim()).whereType<String>().toSet();
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final title = match.group(1)!.trim();
      final exists = existingTitles.contains(title);
      spans.add(
        TextSpan(
          text: title,
          style: TextStyle(
            color: exists ? const Color(0xFF8AA7FF) : Colors.white38,
            decoration: exists ? TextDecoration.underline : TextDecoration.lineThrough,
            decorationColor: exists ? const Color(0xFF8AA7FF) : Colors.white38,
            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final target = allNotes.where((n) => n.title?.trim() == title).firstOrNull;
              if (target != null) {
                _openEditor(note: target);
              }
            },
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            height: 1.45,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _greetingName();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0F1A),
              Color(0xFF10182A),
              Color(0xFF0C1220),
            ],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ref.watch(notesProvider(widget.authUser.uid)).when(
            data: (ownNotes) {
              final sharedNotes = ref
                  .watch(sharedNotesProvider(widget.authUser.uid))
                  .valueOrNull;
              final notes = [
                ...ownNotes,
                if (sharedNotes != null)
                  ...sharedNotes.where((note) =>
                      note.sharedBy != widget.authUser.uid),
              ];
              final filteredNotes = notes.where((note) {
                if (_activeTag != null &&
                    !(note.tags ?? const []).contains(_activeTag)) {
                  return false;
                }

                if (_query.isEmpty) {
                  return true;
                }

                final haystack = '${note.title ?? ''} ${note.content ?? ''}'.toLowerCase();
                return haystack.contains(_query.toLowerCase());
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: Colors.transparent,
                    titleSpacing: 20,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note Log',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                        Text(
                          'Dark workspace for your thoughts',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.white54,
                              ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Filter by tag',
                        onPressed: () => _showContextSwitcher(notes),
                        icon: _activeTag != null
                            ? Badge(
                                isLabelVisible: true,
                                label: const Text(''),
                                child: const Icon(Icons.filter_list_rounded),
                              )
                            : const Icon(Icons.filter_list_rounded),
                      ),
                      const ThemeToggleButton(),
                      ref.watch(dueCountProvider(widget.authUser.uid)).when(
                        data: (count) => Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: IconButton(
                            tooltip: 'Study',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReviewView(
                                  authUser: widget.authUser,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.school_rounded),
                          ),
                        ),
                        loading: () => IconButton(
                          tooltip: 'Study',
                          onPressed: null,
                          icon: const Icon(Icons.school_rounded),
                        ),
                        error: (_, _) => IconButton(
                          tooltip: 'Study',
                          onPressed: null,
                          icon: const Icon(Icons.school_rounded),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: () => ref.read(authServiceProvider).logOut(),
                        icon: const Icon(Icons.logout_rounded),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF17233B), Color(0xFF141B2D)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFF27314A)),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $userName',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Capture ideas, draft notes, and keep them organized in one calm workspace.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                InfoChip(
                                  icon: Icons.sticky_note_2_outlined,
                                  label: '${notes.length} notes',
                                ),
                                InfoChip(
                                  icon: Icons.push_pin_outlined,
                                  label: '${notes.where((note) => note.isPinned).length} pinned',
                                ),
                                InfoChip(
                                  icon: Icons.palette_outlined,
                                  label: '${_palette.length} themes',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _query = value.trim());
                        },
                        decoration: InputDecoration(
                          hintText: 'Search notes',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (_activeTag != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2340),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF27314A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sell_outlined,
                                  color: Colors.white70, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Focus: $_activeTag',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Clear filter',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => _activeTag = null),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (filteredNotes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyNotesState(
                        query: _query,
                        activeTag: _activeTag,
                        onCreate: () => _openEditor(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      sliver: SliverList.separated(
                        itemCount: filteredNotes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          final color = _palette[note.colorIndex % _palette.length];

                          return GestureDetector(
                            onTap: () => _openEditor(note: note),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF141B2D),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: note.isPinned ? color.withValues(alpha: 0.6) : const Color(0xFF27314A),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            note.displayTitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'pin':
                                                _togglePin(note);
                                                break;
                                              case 'delete':
                                                _deleteNote(note);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'pin',
                                              child: Text(note.isPinned ? 'Unpin' : 'Pin'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    _buildLinkPreview(note, notes),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        if (note.isPinned)
                                          TagChip(
                                            color: color,
                                            label: 'Pinned',
                                            icon: Icons.push_pin,
                                          ),
                                        if (note.isLocked)
                                          TagChip(
                                            color: color,
                                            label: 'Locked',
                                            icon: Icons.lock,
                                          ),
                                        if (note.selfDestructAt != null)
                                          TagChip(
                                            color: color,
                                            label: 'Timer',
                                            icon: Icons.timer_outlined,
                                          ),
                                        if (note.selfDestructOnRead)
                                          TagChip(
                                            color: color,
                                            label: 'Read-once',
                                            icon: Icons.visibility_off_outlined,
                                          ),
                                        if ((note.collaborators ?? []).isNotEmpty)
                                          TagChip(
                                            color: const Color(0xFF8AA7FF),
                                            label: 'Shared',
                                            icon: Icons.group_outlined,
                                          ),
                                        const Spacer(),
                                        Text(
                                          _timeLabel(note.updatedAt),
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Colors.white54,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(child: Text('Unable to load notes.')),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
    );
  }
}
