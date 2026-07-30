import 'package:flutter/material.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/presentation/note_editor_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/empty_notes_state.dart';
import 'package:mynotes/features/notes/presentation/widgets/info_chip.dart';
import 'package:mynotes/features/notes/presentation/widgets/tag_chip.dart';
import 'package:mynotes/widgets/theme_toggle_button.dart';

class NotesHomeView extends StatefulWidget {
  final AuthService authService;
  final AuthUser authUser;

  const NotesHomeView({
    super.key,
    required this.authService,
    required this.authUser,
  });

  @override
  State<NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends State<NotesHomeView> {
  final NotesService _notesService = NotesService.instance();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<Color> _palette = [
    Color(0xFF86E7C8),
    Color(0xFF8AA7FF),
    Color(0xFFFFC46B),
    Color(0xFFFF8FA3),
    Color(0xFF9D93FF),
    Color(0xFF67D3FF),
  ];

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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteEditorView(
          authUser: widget.authUser,
          notesService: _notesService,
          note: note,
        ),
      ),
    );
  }

  Future<void> _togglePin(Note note) async {
    await _notesService.togglePin(uid: widget.authUser.uid, note: note);
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
      await _notesService.deleteNote(uid: widget.authUser.uid, noteId: note.id);
    }
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
          child: StreamBuilder<List<Note>>(
            stream: _notesService.watchNotes(widget.authUser.uid),
            builder: (context, snapshot) {
              final notes = snapshot.data ?? const <Note>[];
              final filteredNotes = notes.where((note) {
                if (_query.isEmpty) {
                  return true;
                }

                final haystack = '${note.title} ${note.content}'.toLowerCase();
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
                      const ThemeToggleButton(),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: () => widget.authService.logOut(),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (snapshot.hasError)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('Unable to load notes.'),
                      ),
                    )
                  else if (snapshot.connectionState == ConnectionState.waiting && notes.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filteredNotes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyNotesState(
                        query: _query,
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
                                    Text(
                                      note.previewText,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.white70,
                                            height: 1.45,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        if (note.isPinned)
                                          TagChip(
                                            color: color,
                                            label: 'Pinned',
                                            icon: Icons.push_pin,
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
