import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:mynotes/core/analytics/analytics_consent_store.dart';
import 'package:mynotes/core/analytics/consent_providers.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/async_states.dart';
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
import 'package:mynotes/features/notes/presentation/widgets/pinned_note_card.dart';
import 'package:mynotes/features/collaboration/models/join_request.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/presentation/review_view.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';
import 'package:mynotes/features/capture/services/quick_capture_service.dart';
import 'package:mynotes/features/reminders/reminder_providers.dart';

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

  StreamSubscription<Uri>? _uriSub;
  final QuickCaptureService _quickCapture = QuickCaptureService();
  StreamSubscription<List<JoinRequest>>? _requestSub;
  Timer? _expiryTimer;
  DateTime? _scheduledExpiry;

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
        await ref.read(joinLinkProcessorProvider).processPending();
      } catch (error, stack) {
        AppErrorHandler().handle(error, stack);
      }
      _deleteExpired();
      _purgeTrash();
      unawaited(_startReminders());
      unawaited(_quickCapture.start((text) => _openEditor(initialContent: text)));
      unawaited(_maybeAskAnalyticsConsent());
      _watchOwnerRequests();
      _listenForLinks();
    });
  }

  void _deleteExpired() {
    ref
        .read(notesServiceProvider)
        .deleteExpiredNotes(widget.authUser.uid)
        .catchError(AppErrorHandler().handle);
  }

  void _purgeTrash() {
    ref
        .read(notesServiceProvider)
        .purgeTrash(widget.authUser.uid)
        .catchError(AppErrorHandler().handle);
  }

  /// Schedule this device's reminder notifications, and open the note when
  /// one is tapped (or launched the app).
  Future<void> _startReminders() async {
    final reminders = ref.read(reminderServiceProvider);
    await reminders.init(onOpen: _openNoteById);
    final own = ref.read(notesProvider(widget.authUser.uid)).valueOrNull;
    if (own != null) await reminders.sync(own);
    final launchId = await reminders.launchNoteId();
    if (launchId != null) await _openNoteById(launchId);
  }

  Future<void> _openNoteById(String noteId) async {
    final provider = notesProvider(widget.authUser.uid);
    final List<Note> notes = ref.read(provider).valueOrNull ?? await ref.read(provider.future);
    final note = notes.where((n) => n.id == noteId && !n.isTrashed).firstOrNull;
    if (note != null && mounted) await _openEditor(note: note);
  }

  /// Arm a single timer for the next self-destruct among the visible notes.
  /// When it fires the list is rebuilt (hiding the note, shared ones too) and
  /// this user's expired notes are deleted. Re-armed on every build; a no-op
  /// when the next expiry has not changed.
  void _scheduleExpiry(List<Note> notes) {
    final next = Note.nextExpiry(notes);
    if (next == _scheduledExpiry) return;
    _expiryTimer?.cancel();
    _scheduledExpiry = next;
    if (next == null) return;
    // A second of slack so the note is past due (not equal) when we look.
    final delay = next.difference(DateTime.now()) + const Duration(seconds: 1);
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _scheduledExpiry = null;
      if (!mounted) return;
      setState(() {});
      _deleteExpired();
    });
  }

  void _listenForLinks() {
    _uriSub = AppLinks().uriLinkStream.listen((uri) {
      ref.read(joinLinkProcessorProvider).handleUri(uri).catchError(AppErrorHandler().handle);
    }, onError: AppErrorHandler().handle);
  }

  void _watchOwnerRequests() {
    _requestSub =
        ref.read(shareServiceProvider).watchOwnerJoinRequests(widget.authUser.uid).listen((requests) async {
      for (final request in requests.where((r) => r.status == 'approved')) {
        try {
          await ref.read(shareServiceProvider).completeShareForRequest(
                ownerUid: widget.authUser.uid,
                token: request.token,
                recipientUid: request.recipientUid,
              );
        } catch (error, stack) {
          AppErrorHandler().handle(error, stack);
        }
      }
    }, onError: AppErrorHandler().handle);
  }

  /// One-time analytics consent prompt shown on first authenticated launch.
  Future<void> _maybeAskAnalyticsConsent() async {
    final status = await AnalyticsConsentStore.read();
    if (status != null || !mounted) return;
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Help improve Notely'),
        content: const Text(
          "We'd like to collect anonymous usage data to understand how "
          'Notely is used and make it better. This never includes your notes '
          "or anything you type. You can change this anytime in Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (granted == null || !mounted) return;
    await ref.read(consentCoordinatorProvider).recordDecision(granted);
    ref.invalidate(consentStatusProvider);
  }

  @override
  void dispose() {
    _uriSub?.cancel();
    _requestSub?.cancel();
    _expiryTimer?.cancel();
    _quickCapture.stop();
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

  String _joinMessage(JoinResult result) {
    return switch (result.status) {
      JoinStatus.notFound => 'This link is invalid or has expired.',
      JoinStatus.ownerLink => 'You opened your own share link.',
      JoinStatus.alreadyShared => 'This note is already shared with you.',
      JoinStatus.pending => 'Request sent. The note will appear here once the owner approves it.',
      JoinStatus.approved => "Almost there. The note will appear here the next time the owner opens Notely.",
      JoinStatus.shared => 'The note is now shared with you.',
    };
  }

  Future<void> _openEditor({Note? note, String? initialContent}) async {
    if (note != null && note.decryptionFailed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("This note can't be decrypted on this device. If you reset "
            'your password, sign out and unlock with your recovery code.'),
      ));
      return;
    }
    if (note != null && note.isLocked) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => LockScreen(
          uid: widget.authUser.uid,
          note: note,
          builder: (unlocked) => NoteEditorView(authUser: widget.authUser, note: unlocked),
        ),
      ));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => NoteEditorView(authUser: widget.authUser, note: note, initialContent: initialContent),
      ));
    }
  }

  void _reportFailure(Object error, StackTrace stack, String message) {
    AppErrorHandler().handle(error, stack);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _togglePin(Note note) async {
    try {
      await ref.read(notesServiceProvider).togglePin(uid: widget.authUser.uid, note: note);
    } catch (error, stack) {
      _reportFailure(error, stack, 'Could not update the note.');
    }
  }

  Future<void> _archive(Note note) async {
    try {
      await ref.read(notesServiceProvider).setArchived(uid: widget.authUser.uid, note: note, archived: true);
    } catch (error, stack) {
      _reportFailure(error, stack, 'Could not archive note');
      return;
    }
    if (!mounted) return;
    showArchiveToast(context, () async {
      try {
        await ref.read(notesServiceProvider).setArchived(uid: widget.authUser.uid, note: note, archived: false);
      } catch (error, stack) {
        _reportFailure(error, stack, 'Could not restore the note.');
      }
    });
  }

  Future<void> _bulkArchive() async {
    final notes = _selectedNotes();
    try {
      await ref.read(notesServiceProvider).archiveMany(uid: widget.authUser.uid, notes: notes);
    } catch (error, stack) {
      _reportFailure(error, stack, 'Could not archive the selected notes.');
    }
    if (mounted) setState(() { _selected.clear(); _selectMode = false; });
  }

  Future<void> _bulkDelete() async {
    final notes = _selectedNotes().where((n) => n.sharedBy == null || n.sharedBy == widget.authUser.uid).toList();
    final service = ref.read(notesServiceProvider);
    final uid = widget.authUser.uid;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.moveToTrash(uid: uid, notes: notes);
      messenger.showSnackBar(SnackBar(
        content: Text('Moved ${notes.length} ${notes.length == 1 ? 'note' : 'notes'} to trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => service.restoreFromTrash(uid: uid, notes: notes).catchError(AppErrorHandler().handle),
        ),
      ));
    } catch (error, stack) {
      _reportFailure(error, stack, "Couldn't move the selected notes to the trash.");
    }
    if (mounted) setState(() { _selected.clear(); _selectMode = false; });
  }

  Future<void> _bulkPin() async {
    final notes = _selectedNotes();
    final target = !notes.every((n) => n.isPinned);
    try {
      await ref.read(notesServiceProvider).setPinnedMany(uid: widget.authUser.uid, notes: notes, pinned: target);
    } catch (error, stack) {
      _reportFailure(error, stack, 'Could not update the selected notes.');
    }
    if (mounted) setState(() { _selected.clear(); _selectMode = false; });
  }

  List<Note> _selectedNotes() {
    final all = _mergedNotes();
    return all.where((n) => _selected.contains(n.id)).toList();
  }

  List<Note> _mergedNotes() {
    final own = ref.read(notesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    final shared = ref.read(sharedNotesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    return [...own, ...shared.where((n) => n.sharedBy != widget.authUser.uid)].where((n) => !n.isTrashed).toList();
  }

  // Filtering and sorting run only when the inputs change, not on every
  // rebuild (typing, dialogs, timers all rebuild this widget).
  // The provider lists are new objects on every snapshot, so identity is a
  // cheap and exact change check. The expiry timer changes _scheduledExpiry,
  // which forces a recompute when a note expires.
  List<Note>? _visibleCache;
  List<Note>? _cachedOwn;
  List<Note>? _cachedShared;
  String? _cachedQuery;
  String? _cachedTag;
  String? _cachedFilter;
  NoteSort? _cachedSort;
  DateTime? _cachedExpiry;

  List<Note> _visible(List<Note> own, List<Note> shared, List<Note> notes) {
    final cached = _visibleCache;
    if (cached != null &&
        identical(own, _cachedOwn) &&
        identical(shared, _cachedShared) &&
        _query == _cachedQuery &&
        _activeTag == _cachedTag &&
        _filter == _cachedFilter &&
        _sort == _cachedSort &&
        _scheduledExpiry == _cachedExpiry) {
      return cached;
    }
    _cachedOwn = own;
    _cachedShared = shared;
    _cachedQuery = _query;
    _cachedTag = _activeTag;
    _cachedFilter = _filter;
    _cachedSort = _sort;
    _cachedExpiry = _scheduledExpiry;
    return _visibleCache = _computeVisible(notes);
  }

  List<Note> _computeVisible(List<Note> notes) {
    var list = notes.where((n) => !n.isArchived).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((n) =>
        n.title?.toLowerCase().contains(q) == true ||
        (!n.isLocked && n.content?.toLowerCase().contains(q) == true) ||
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
    // Forget biometric unlock entries for notes deleted or no longer PIN-locked.
    ref.listen<AsyncValue<List<Note>>>(notesProvider(widget.authUser.uid), (previous, next) {
      final notes = next.valueOrNull;
      if (notes == null) return;
      ref
          .read(biometricUnlockServiceProvider)
          .prune(widget.authUser.uid, notes)
          .catchError(AppErrorHandler().handle);
      ref.read(reminderServiceProvider).sync(notes);
    });
    ref.listen<JoinResult?>(joinResultProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(joinResultProvider.notifier).state = null;
      });
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share link'),
          content: Text(_joinMessage(next)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
    final ownAsync = ref.watch(notesProvider(widget.authUser.uid));
    final sharedAsync = ref.watch(sharedNotesProvider(widget.authUser.uid));
    // Before the first snapshot there is nothing to show yet: that is
    // "loading", never "no notes" (see the slivers below).
    final own = ownAsync.valueOrNull ?? const <Note>[];
    final shared = sharedAsync.valueOrNull ?? const <Note>[];
    final notes = [...own, ...shared.where((n) => n.sharedBy != widget.authUser.uid)]
        .where((n) => !n.isExpired && !n.isTrashed)
        .toList();
    _scheduleExpiry(notes);
    final visible = _visible(own, shared, notes);
    final pinned = visible.where((n) => n.isPinned).toList();
    final rest = visible.where((n) => !n.isPinned).toList();

    final due = ref.watch(dueCountProvider(widget.authUser.uid)).valueOrNull ?? 0;

    return Scaffold(
        backgroundColor: NotelyTheme.of(context).bg,
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
                      noteCount: ownAsync.hasValue ? notes.where((n) => !n.isArchived).length : null,
                      onOpenAccount: _openAccount,
                      onToggleSelect: () => setState(() { _selectMode = !_selectMode; _selected.clear(); }),
                      selectMode: _selectMode,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: NoteSearchField(controller: _searchController, onChanged: (v) => setState(() => _query = v.trim())),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                if (due > 0 && !_selectMode)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _StudyRow(
                        due: due,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ReviewView(authUser: widget.authUser),
                        )),
                      ),
                    ),
                  ),
                if (_activeTag != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(child: _FocusBar(tag: _activeTag!, onClear: () => setState(() => _activeTag = null))),
                  ),
                if (_selectMode)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(child: _SelectionBar(count: _selected.length, onPin: _bulkPin, onArchive: _bulkArchive, onDelete: _bulkDelete)),
                  ),
                // Notes are on screen but a refresh failed: say so, keep them.
                if (ownAsync.hasValue && ownAsync.hasError)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: InlineErrorBanner(
                        message: "Couldn't refresh your notes. Showing what's on this device.",
                        onRetry: _retryLoad,
                      ),
                    ),
                  ),
                if (sharedAsync.hasError)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: InlineErrorBanner(
                        message: "Couldn't load notes shared with you.",
                        onRetry: _retryLoad,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (!ownAsync.hasValue)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ownAsync.hasError
                        ? ErrorState(title: "Couldn't load your notes", error: ownAsync.error!, onRetry: _retryLoad)
                        : const LoadingState(),
                  )
                else if (visible.isEmpty)
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
                  if (pinned.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 12),
                      sliver: SliverToBoxAdapter(
                        child: SizedBox(
                          height: 208,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: pinned.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final note = pinned[index];
                              return PinnedNoteCard(
                                note: note,
                                relativeTime: _timeLabel(note.updatedAt),
                                selectMode: _selectMode,
                                selected: _selected.contains(note.id),
                                onOpen: () => _openEditor(note: note),
                                onSelect: () => setState(() {
                                  if (_selected.contains(note.id)) {
                                    _selected.remove(note.id);
                                  } else {
                                    _selected.add(note.id);
                                  }
                                }),
                                onUnpin: () => _togglePin(note),
                                onArchive: () => _archive(note),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  if (rest.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                      sliver: SliverToBoxAdapter(child: _SectionHeader(label: pinned.isEmpty ? 'Notes' : 'Other notes', count: rest.length, pinned: false)),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                    sliver: SliverList.separated(
                      itemCount: rest.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCard(rest[index], notes),
                    ),
                  ),
                ],
              ],
            ),
            // Only once notes have loaded: over a spinner or an error it
            // would cover "Try again" on short screens.
            if (!_selectMode && ownAsync.hasValue) HomeFab(onPressed: () => _openEditor()),
          ],
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

  void _retryLoad() {
    ref.invalidate(notesProvider(widget.authUser.uid));
    ref.invalidate(sharedNotesProvider(widget.authUser.uid));
  }

  void _openAccount() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
      Text(label, style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.text2)),
      const SizedBox(width: 8),
      Text(
        '$count',
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          color: notely.text3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ]);
  }
}

/// Flashcards due today. Shown only when there is something to review.
class _StudyRow extends StatelessWidget {
  final int due;
  final VoidCallback onTap;
  const _StudyRow({required this.due, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Material(
      color: notely.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: notely.border)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(Icons.style_outlined, size: 18, color: notely.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$due ${due == 1 ? 'card' : 'cards'} to review today',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text),
                ),
              ),
              Text('Study', style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.violet)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: notely.violet),
            ]),
          ),
        ),
      ),
    );
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
      height: 40,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(color: notely.violetSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: notely.violetSoft2)),
      child: Row(children: [
        Icon(Icons.sell_outlined, size: 16, color: notely.violetInk),
        const SizedBox(width: 8),
        Expanded(child: Text('Showing $tag', style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.violetInk))),
        IconButton(tooltip: 'Clear filter', onPressed: onClear, icon: Icon(Icons.close, size: 16, color: notely.violetInk)),
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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: notely.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: notely.borderStrong)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$count selected', style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.text)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: danger ? notely.danger : notely.text2),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500, color: danger ? notely.danger : notely.text2)),
      ]),
    ));
  }
}
