import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/features/account/presentation/account_sheet.dart';
import 'package:mynotes/features/lock/presentation/lock_screen.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/note_sort.dart';
import 'package:mynotes/features/notes/presentation/note_editor_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/empty_state.dart';
import 'package:mynotes/features/notes/presentation/widgets/home_fab.dart';
import 'package:mynotes/features/notes/presentation/widgets/list_header.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_card.dart';
import 'package:mynotes/features/notes/presentation/widgets/note_preview.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

class NotesHomeView extends ConsumerStatefulWidget {
  final AuthUser authUser;
  const NotesHomeView({super.key, required this.authUser});
  @override
  ConsumerState<NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends ConsumerState<NotesHomeView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _activeTag;
  String _filter = 'All';
  NoteSort _sort = NoteSort.updated;
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(shareServiceProvider).ensureUserProfile(
              uid: widget.authUser.uid,
              email: widget.authUser.email,
              displayName: widget.authUser.displayName,
            );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _userName() {
    final displayName = widget.authUser.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName.split(' ').first;
    final email = widget.authUser.email.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Writer';
  }

  String _timeLabel(DateTime updatedAt) {
    final difference = DateTime.now().difference(updatedAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';
  }

  Future<void> _openEditor({Note? note}) async {
    if (note != null && note.isLocked) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => LockScreen(noteId: note.id, pinHash: note.pinHash, pinSalt: note.pinSalt, child: NoteEditorView(authUser: widget.authUser, note: note))));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => NoteEditorView(authUser: widget.authUser, note: note)));
    }
  }

  Future<void> _togglePin(Note note) async {
    try {
      await ref.read(notesServiceProvider).togglePin(uid: widget.authUser.uid, note: note);
    } catch (_) {}
  }

  Future<void> _archive(Note note) async {
    try {
      await ref.read(notesServiceProvider).setArchived(uid: widget.authUser.uid, note: note, archived: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not archive note')));
      return;
    }
    if (!mounted) return;
    showArchiveToast(context, () async {
      try {
        await ref.read(notesServiceProvider).setArchived(uid: widget.authUser.uid, note: note, archived: false);
      } catch (_) {}
    });
  }

  Future<void> _bulkArchive() async {
    final notes = _selectedNotes();
    try {
      await ref.read(notesServiceProvider).archiveMany(uid: widget.authUser.uid, notes: notes);
    } catch (_) {}
    setState(() { _selected.clear(); _selectMode = false; });
  }

  Future<void> _bulkDelete() async {
    final notes = _selectedNotes();
    final confirmed = await GlassDialog.show<bool>(
      context: context,
      title: 'Delete ${notes.length} note${notes.length == 1 ? '' : 's'}?',
      message: 'This removes them permanently.',
      actions: [
        GlassDialogAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
        GlassDialogAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (confirmed != true) return;
    try {
      await ref.read(notesServiceProvider).deleteMany(uid: widget.authUser.uid, notes: notes);
    } catch (_) {}
    if (mounted) setState(() { _selected.clear(); _selectMode = false; });
  }

  Future<void> _bulkPin() async {
    final notes = _selectedNotes();
    final target = !notes.every((n) => n.isPinned);
    try {
      await ref.read(notesServiceProvider).setPinnedMany(uid: widget.authUser.uid, notes: notes, pinned: target);
    } catch (_) {}
    if (mounted) setState(() { _selected.clear(); _selectMode = false; });
  }

  List<Note> _selectedNotes() {
    final all = _mergedNotes();
    return all.where((n) => _selected.contains(n.id)).toList();
  }

  List<Note> _mergedNotes() {
    final own = ref.read(notesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    final shared = ref.read(sharedNotesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    return [...own, ...shared.where((n) => n.sharedBy != widget.authUser.uid)];
  }

  List<Note> _visible(List<Note> notes) {
    var list = notes.where((n) => !n.isArchived).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((n) =>
        n.title?.toLowerCase().contains(q) == true ||
        n.content?.toLowerCase().contains(q) == true ||
        (n.tags ?? const <String>[]).any((t) => t.toLowerCase().contains(q))).toList();
    }
    if (_activeTag != null) {
      list = list.where((n) => (n.tags ?? const <String>[]).contains(_activeTag)).toList();
    }
    if (_filter == 'Pinned') {
      list = list.where((n) => n.isPinned).toList();
    } else if (_filter == 'Recent') {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      list = list.where((n) => n.updatedAt.isAfter(cutoff)).toList();
    }
    final comparator = noteComparator(_sort);
    list.sort(comparator);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final own = ref.watch(notesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    final shared = ref.watch(sharedNotesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    final notes = [...own, ...shared.where((n) => n.sharedBy != widget.authUser.uid)];
    final visible = _visible(notes);
    final pinned = visible.where((n) => n.isPinned).toList();
    final rest = visible.where((n) => !n.isPinned).toList();

    return GlassPage(
      background: const NotelyBackground(),
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: ListHeader(
                      userName: _userName(),
                      noteCount: notes.where((n) => !n.isArchived).length,
                      onOpenAccount: _openAccount,
                      onToggleSelect: () => setState(() { _selectMode = !_selectMode; _selected.clear(); }),
                      selectMode: _selectMode,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: NoteSearchField(controller: _searchController, onChanged: (v) => setState(() => _query = v.trim())),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FilterChips(active: _filter, pinnedCount: notes.where((n) => n.isPinned && !n.isArchived).length, onChanged: (v) => setState(() => _filter = v)),
                        SortMenu(sort: _sort, onChanged: (v) => setState(() => _sort = v)),
                      ],
                    ),
                  ),
                ),
                if (_activeTag != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(child: _FocusBar(tag: _activeTag!, onClear: () => setState(() => _activeTag = null))),
                  ),
                if (_selectMode)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(child: _SelectionBar(count: _selected.length, onPin: _bulkPin, onArchive: _bulkArchive, onDelete: _bulkDelete)),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(query: _query, activeTag: _activeTag),
                  )
                else ...[
                  if (pinned.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverToBoxAdapter(child: _SectionHeader(label: 'Pinned', count: pinned.length, pinned: true)),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: pinned.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCard(pinned[index], notes),
                    ),
                  ),
                  if (rest.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      sliver: SliverToBoxAdapter(child: _SectionHeader(label: 'All notes', count: rest.length, pinned: false)),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList.separated(
                      itemCount: rest.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCard(rest[index], notes),
                    ),
                  ),
                ],
              ],
            ),
            if (!_selectMode) HomeFab(onPressed: () => _openEditor()),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildCard(Note note, List<Note> allNotes) {
    return NoteCard(
      note: note,
      selectMode: _selectMode,
      selected: _selected.contains(note.id),
      onSelect: () => setState(() {
        if (_selected.contains(note.id)) { _selected.remove(note.id); } else { _selected.add(note.id); }
      }),
      onPin: () => _togglePin(note),
      onArchive: () => _archive(note),
      onOpen: () => _openEditor(note: note),
      onTagTap: (tag) => setState(() => _activeTag = tag),
      relativeTime: _timeLabel(note.updatedAt),
      preview: buildNotePreview(context, note, allNotes, (n) => _openEditor(note: n)),
    );
  }

  void _openAccount() {
    GlassModalSheet.show<void>(
      context: context,
      showDragIndicator: false,
      builder: (context) => const Material(type: MaterialType.transparency, child: AccountSheet()),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool pinned;
  const _SectionHeader({required this.label, required this.count, required this.pinned});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Row(children: [
      if (pinned) Icon(Icons.push_pin, size: 12, color: notely.violet),
      if (pinned) const SizedBox(width: 7),
      Text(label.toUpperCase(), style: TextStyle(fontFamily: 'Geist', fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: notely.text3)),
      const SizedBox(width: 6),
      Text('$count', style: TextStyle(fontSize: 11.5, color: notely.text4)),
      const SizedBox(width: 4),
      Expanded(child: Container(height: 1, color: notely.border)),
    ]);
  }
}

class _FocusBar extends StatelessWidget {
  final String tag;
  final VoidCallback onClear;
  const _FocusBar({required this.tag, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: notely.violetSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: notely.violetSoft2)),
      child: Row(children: [
        Icon(Icons.sell_outlined, size: 16, color: notely.violetInk),
        const SizedBox(width: 8),
        Expanded(child: Text('Focus: $tag', style: TextStyle(fontWeight: FontWeight.w700, color: notely.violetInk))),
        InkWell(onTap: onClear, customBorder: const CircleBorder(), child: Icon(Icons.close, size: 16, color: notely.violetInk)),
      ]),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  const _SelectionBar({required this.count, required this.onPin, required this.onArchive, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: notely.violetSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: notely.violetSoft2)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$count selected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: notely.violetInk)),
        Row(children: [
          _SmallAction(icon: Icons.push_pin_outlined, label: 'Pin', onTap: onPin),
          _SmallAction(icon: Icons.archive_outlined, label: 'Archive', onTap: onArchive),
          _SmallAction(icon: Icons.delete_outline, label: 'Delete', onTap: onDelete, danger: true),
        ]),
      ]),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _SmallAction({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: danger ? const Color(0xFFB91C1C) : notely.violetInk),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: danger ? const Color(0xFFB91C1C) : notely.violetInk)),
      ]),
    ));
  }
}
