import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';
import 'package:mynotes/features/capture/providers/capture_providers.dart';

import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/version_history_view.dart';
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
  late bool _isStudyMaterial;
  late bool _selfDestructOnRead;
  DateTime? _selfDestructAt;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isRecording = false;
  List<String> _audioAttachments = [];
  double? _latitude;
  double? _longitude;
  String? _placeName;
  bool _isCapturingLocation = false;
  List<Note> _backlinks = [];
  bool _loadingBacklinks = false;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  final LayerLink _suggestionLayerLink = LayerLink();
  final FocusNode _contentFocusNode = FocusNode();
  final TextEditingController _commentController = TextEditingController();
  bool _isAddingComment = false;
  List<String> _collaborators = [];
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _selectedColorIndex = note?.colorIndex ?? 0;
    _isPinned = note?.isPinned ?? false;
    _isStudyMaterial = note?.isStudyMaterial ?? false;
    _selfDestructAt = note?.selfDestructAt;
    _selfDestructOnRead = note?.selfDestructOnRead ?? false;
    _audioAttachments = note?.audioAttachments ?? [];
    _latitude = note?.latitude;
    _longitude = note?.longitude;
    _collaborators = note?.collaborators ?? [];
    _tags = note?.tags ?? [];

    _contentController.addListener(_onContentChanged);

    if (note != null) {
      _loadBacklinks();
    }

    if (note?.selfDestructOnRead == true) {
      _handleSelfDestructOnRead();
    }
  }

  void _onContentChanged() {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid || sel.baseOffset != sel.extentOffset) {
      _hideSuggestions();
      return;
    }
    final cursorPos = sel.baseOffset;
    if (cursorPos < 2) {
      _hideSuggestions();
      return;
    }
    final before = text.substring(0, cursorPos);
    final openIdx = before.lastIndexOf('[[');
    if (openIdx == -1 || openIdx < cursorPos - 50) {
      _hideSuggestions();
      return;
    }
    final afterOpen = before.substring(openIdx + 2);
    if (afterOpen.contains(']]')) {
      _hideSuggestions();
      return;
    }
    _fetchSuggestions(afterOpen);
  }

  void _hideSuggestions() {
    if (_showSuggestions) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    final titles = await ref.read(notesServiceProvider).searchTitles(
      widget.authUser.uid,
      query,
    );
    if (!mounted) return;
    setState(() {
      _suggestions = titles.where((t) => t.toLowerCase().contains(query.toLowerCase())).toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  void _insertSuggestion(String title) {
    final text = _contentController.text;
    final cursorPos = _contentController.selection.baseOffset;
    final before = text.substring(0, cursorPos);
    final openIdx = before.lastIndexOf('[[');
    if (openIdx == -1) return;
    final closeIdx = text.indexOf(']]', cursorPos);
    int endIdx = closeIdx != -1 ? closeIdx + 2 : cursorPos;
    final newText = '${text.substring(0, openIdx)}[[$title]]${text.substring(endIdx)}';
    _contentController.text = newText;
    final newCursor = openIdx + title.length + 4;
    _contentController.selection = TextSelection.collapsed(offset: newCursor);
    _hideSuggestions();
  }

  Future<void> _loadBacklinks() async {
    final note = widget.note;
    if (note == null) return;
    setState(() => _loadingBacklinks = true);
    try {
      final backlinks = await ref.read(notesServiceProvider).getBacklinks(
        widget.authUser.uid,
        note.id,
      );
      if (!mounted) return;
      setState(() {
        _backlinks = backlinks;
        _loadingBacklinks = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBacklinks = false);
    }
  }

  Future<void> _showOcrSheet() async {
    final controller = _contentController;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final notely = NotelyTheme.of(context);
        return Material(
          type: MaterialType.transparency,
          child: NotelySheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.text_snippet, color: notely.text2),
                  const SizedBox(width: 12),
                  Text(
                    'Extract text from image',
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('camera'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('gallery'),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                  style: FilledButton.styleFrom(
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
        );
      },
    );

    if (result == null || !mounted) return;

    final ocrService = ref.read(ocrServiceProvider);
    setState(() => _isSaving = true);
    try {
      final text = await ocrService.pickAndRecognizeText(
        fromCamera: result == 'camera',
      );
      if (text == null || text.isEmpty || !mounted) return;

      final cursorPos = controller.selection.baseOffset;
      final currentText = controller.text;
      final insertPos = cursorPos < 0 || cursorPos > currentText.length
          ? currentText.length
          : cursorPos;
      final newText = currentText.substring(0, insertPos) +
          text +
          currentText.substring(insertPos);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: insertPos + text.length,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _isCapturingLocation = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final result = await locationService.getCurrentLocation();
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _placeName = result.placeName;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturingLocation = false);
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    final permitted = await voiceService.requestPermission();
    if (!permitted || !mounted) return;

    setState(() => _isRecording = true);
    await voiceService.startRecording();
  }

  Future<void> _stopVoiceRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    final result = await voiceService.stopRecordingAndTranscribe();
    if (!mounted) return;

    setState(() => _isRecording = false);

    if (result == null) return;

    final transcription = result.transcription;
    final filePath = result.filePath;

    if (transcription.isNotEmpty) {
      final controller = _contentController;
      final cursorPos = controller.selection.baseOffset;
      final currentText = controller.text;
      final insertPos = cursorPos < 0 || cursorPos > currentText.length
          ? currentText.length
          : cursorPos;
      final newText = currentText.substring(0, insertPos) +
          transcription +
          currentText.substring(insertPos);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: insertPos + transcription.length,
      );
    }

    _audioAttachments = [..._audioAttachments, filePath];
  }

  Future<void> _handleSelfDestructOnRead() async {
    final note = widget.note;
    if (note == null) return;

    try {
      await ref.read(notesServiceProvider).deleteNote(
        uid: widget.authUser.uid,
        noteId: note.id,
      );
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This note has self-destructed')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _commentController.dispose();
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
          isStudyMaterial: _isStudyMaterial,
          audioAttachments: _audioAttachments,
          latitude: _latitude,
          longitude: _longitude,
          tags: _tags,
          selfDestructAt: _selfDestructAt,
          selfDestructOnRead: _selfDestructOnRead,
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
            isStudyMaterial: _isStudyMaterial,
            selfDestructAt: _selfDestructAt,
            selfDestructOnRead: _selfDestructOnRead,
            audioAttachments: _audioAttachments,
            latitude: _latitude,
            longitude: _longitude,
            tags: _tags,
          ),
        );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save note: $e')),
        );
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

    final confirmed = await showNotelyDialog<bool>(
      context: context,
      title: 'Delete note?',
      message: 'This removes the note permanently.',
      actions: [
        NotelyDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        NotelyDialogAction(
          label: 'Delete',
          isDestructive: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
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
        final pin = await showNotelyDialog<String>(
          context: context,
          title: 'Set a PIN',
          content: TextField(
            controller: pinController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter PIN',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            NotelyDialogAction(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(null),
            ),
            NotelyDialogAction(
              label: 'Set PIN',
              isPrimary: true,
              onPressed: () => Navigator.of(context).pop(pinController.text),
            ),
          ],
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

  Future<void> _showSelfDestructSheet() async {
    DateTime? pickedDate = _selfDestructAt;
    bool onRead = _selfDestructOnRead;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: _SelfDestructSheet(
          initialDate: pickedDate,
          initialOnRead: onRead,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selfDestructAt = result['date'] as DateTime?;
        _selfDestructOnRead = result['onRead'] as bool;
      });
    }
  }

  Future<void> _showTagsDialog() async {
    final allNotes =
        ref.read(notesProvider(widget.authUser.uid)).valueOrNull ?? const <Note>[];
    final allTags = <String>{};
    for (final note in allNotes) {
      allTags.addAll(note.tags ?? const []);
    }
    allTags.addAll(_tags);

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: _TagsSheet(
          allTags: allTags,
          initialSelected: List<String>.of(_tags),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _tags = result);
    }
  }

  bool get _isShared {
    if (widget.note == null) return false;
    return _collaborators.isNotEmpty || widget.note!.sharedBy != null;
  }

  Future<void> _showShareSheet() async {
    final note = widget.note;
    if (note == null) return;

    final emailController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: _ShareSheet(
        collaborators: List.of(_collaborators),
        emailController: emailController,
        onAddCollaborator: (email) async {
          final shareService = ref.read(shareServiceProvider);
          final collaboratorUid =
              await shareService.lookupUserByEmail(email);
          await shareService.shareNote(
            uid: widget.authUser.uid,
            note: note,
            collaboratorEmail: email,
            collaboratorName: '',
          );
          messenger.showSnackBar(
            const SnackBar(content: Text('Note shared')),
          );
          return collaboratorUid ?? '';
        },
        onRemoveCollaborator: (collaboratorUid) async {
          final shareService = ref.read(shareServiceProvider);
          await shareService.removeCollaborator(
            uid: widget.authUser.uid,
            note: note,
            collaboratorUid: collaboratorUid,
          );
          if (!mounted) return;
          setState(() {
            _collaborators =
                _collaborators.where((uid) => uid != collaboratorUid).toList();
          });
        },
      ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _addComment(String content) async {
    final note = widget.note;
    if (note == null) return;

    setState(() => _isAddingComment = true);
    try {
      await ref.read(notesServiceProvider).addComment(
            noteOwnerId: note.sharedBy ?? widget.authUser.uid,
            noteId: note.id,
            authorUid: widget.authUser.uid,
            authorName: widget.authUser.displayName ?? widget.authUser.email.split('@').first,
            content: content,
          );
      if (!mounted) return;
      _commentController.clear();
    } finally {
      if (mounted) setState(() => _isAddingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final note = widget.note;
    if (note == null) return;

    try {
      await ref.read(notesServiceProvider).deleteComment(
            noteOwnerId: note.sharedBy ?? widget.authUser.uid,
            noteId: note.id,
            commentId: commentId,
            authorUid: widget.authUser.uid,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final notely = NotelyTheme.of(context);
    final accent = kNotePalette[_selectedColorIndex % kNotePalette.length];

    return GlassPage(
      background: const NotelyBackground(),
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: GlassAppBar(
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          title: Text(
            note == null ? 'New note' : 'Edit note',
            style: TextStyle(fontFamily: 'Geist', fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: notely.text),
          ),
          actions: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.document_scanner),
                    onPressed: _isSaving || _isDeleting ? null : _showOcrSheet,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(_isRecording ? Icons.mic : Icons.mic_none),
                    onPressed: _isSaving || _isDeleting
                        ? null
                        : _isRecording
                            ? _stopVoiceRecording
                            : _startVoiceRecording,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: _isCapturingLocation
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_latitude != null ? Icons.location_on : Icons.location_on_outlined),
                    onPressed:
                        _isSaving || _isDeleting || _isCapturingLocation ? null : _captureLocation,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (note != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(note.isLocked ? Icons.lock : Icons.lock_open),
                      onPressed: _isSaving || _isDeleting ? null : _toggleLock,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        _selfDestructAt != null || _selfDestructOnRead
                            ? Icons.timer
                            : Icons.timer_outlined,
                      ),
                      onPressed: _isSaving || _isDeleting ? null : _showSelfDestructSheet,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      onPressed: _isSaving || _isDeleting ? null : _showShareSheet,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: _isSaving || _isDeleting
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => VersionHistoryView(
                                    authUser: widget.authUser,
                                    noteId: note.id,
                                  ),
                                ),
                              );
                            },
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _isSaving || _isDeleting ? null : _deleteNote,
                      icon: _isDeleting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: notely.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: notely.border),
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
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Study'),
                            selected: _isStudyMaterial,
                            onSelected: (selected) {
                              setState(() => _isStudyMaterial = selected);
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
                        style: const TextStyle(fontFamily: 'Instrument Serif', fontSize: 30, height: 1.1, letterSpacing: -0.6),
                        decoration: const InputDecoration(
                          hintText: 'Note title',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CompositedTransformTarget(
                        link: _suggestionLayerLink,
                        child: TextField(
                          controller: _contentController,
                          focusNode: _contentFocusNode,
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
                      ),
                      if (_showSuggestions)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: notely.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: notely.border),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final title = _suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(Icons.link, size: 18, color: notely.text3),
                                title: Text(
                                  title,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                onTap: () => _insertSuggestion(title),
                              );
                            },
                          ),
                        ),
                      if (_isRecording)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.fiber_manual_record,
                                  color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Recording...',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.redAccent),
                              ),
                            ],
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
                  children: List.generate(kNotePalette.length, (index) {
                    final color = kNotePalette[index];
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _isSaving ? null : _showTagsDialog,
                      icon: const Icon(Icons.sell_outlined, size: 18),
                      label: const Text('Edit tags'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_tags.isEmpty)
                  Text(
                    'No tags yet. Tap "Edit tags" to organize this note.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: notely.text3,
                        ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) {
                      return TagPill(name: tag, style: TagPillStyle.outlined);
                    }).toList(),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Self-destruct',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _isSaving ? null : _showSelfDestructSheet,
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: Text(
                        _selfDestructAt != null || _selfDestructOnRead
                            ? 'Change'
                            : 'Set',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selfDestructAt != null || _selfDestructOnRead)
                  Text(
                    _selfDestructAt != null
                        ? 'Deletes on ${_selfDestructAt!.month}/${_selfDestructAt!.day}/${_selfDestructAt!.year} ${_selfDestructAt!.hour.toString().padLeft(2, '0')}:${_selfDestructAt!.minute.toString().padLeft(2, '0')}'
                        : 'Deletes after first read',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                        ),
                  )
                else
                  Text(
                    'Set a date and time for this note to be deleted automatically.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: notely.text3,
                        ),
                  ),
                if (_audioAttachments.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Audio attachments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ..._audioAttachments.map((path) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: notely.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.audiotrack,
                                color: notely.text2, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                path.split('\\').last.split('/').last,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: notely.text2),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: notely.text2, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _latitude = null;
                          _longitude = null;
                          _placeName = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_placeName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _placeName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: notely.text3,
                            ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 160,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_latitude!, _longitude!),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.flutter.mynotes',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_latitude!, _longitude!),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      backgroundColor: notely.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Icon(Icons.link, color: notely.text2, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Backlinks',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingBacklinks)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_backlinks.isEmpty)
                    Text(
                      'No other notes link to this one.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: notely.text3,
                          ),
                    )
                  else
                      ..._backlinks.map(
                        (bl) => GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NoteEditorView(
                                  authUser: widget.authUser,
                                  note: bl,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: notely.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: notely.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: kNotePalette[bl.colorIndex % kNotePalette.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    bl.displayTitle,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: notely.text2,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: notely.text4, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
                if (_isShared && note != null) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Icon(Icons.comment_outlined, color: notely.text2, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Comments',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      ref.watch(
                        commentsProvider(
                          (noteOwnerId: note.sharedBy ?? widget.authUser.uid, noteId: note.id),
                        ),
                      ).when(
                        data: (comments) => Badge(
                          isLabelVisible: comments.isNotEmpty,
                          label: Text('${comments.length}'),
                          child: Icon(Icons.chat_bubble_outline, color: notely.text3, size: 20),
                        ),
                        loading: () => const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, _) => Icon(Icons.chat_bubble_outline, color: notely.text3, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: notely.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: notely.border),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ref.watch(
                      commentsProvider(
                        (noteOwnerId: note.sharedBy ?? widget.authUser.uid, noteId: note.id),
                      ),
                    ).when(
                      data: (comments) {
                        if (comments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No comments yet.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: notely.text3,
                                    ),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: comments
                              .map(
                                (comment) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: notely.surface2,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              comment.authorName,
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    color: notely.text2,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            _commentTime(comment.createdAt),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: notely.text4,
                                                ),
                                          ),
                                          if (comment.authorUid == widget.authUser.uid)
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, size: 16, color: notely.text4),
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _deleteComment(comment.id),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment.content,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: notely.text2,
                                              height: 1.35,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Unable to load comments.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: notely.text3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          enabled: !_isAddingComment,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isAddingComment ||
                                _commentController.text.trim().isEmpty
                            ? null
                            : () => _addComment(_commentController.text.trim()),
                        icon: _isAddingComment
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _commentTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${time.month}/${time.day}/${time.year}';
  }
}

class _TagsSheet extends StatefulWidget {
  final Set<String> allTags;
  final List<String> initialSelected;

  const _TagsSheet({
    required this.allTags,
    required this.initialSelected,
  });

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
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

class _SelfDestructSheet extends StatefulWidget {
  final DateTime? initialDate;
  final bool initialOnRead;

  const _SelfDestructSheet({
    required this.initialDate,
    required this.initialOnRead,
  });

  @override
  State<_SelfDestructSheet> createState() => _SelfDestructSheetState();
}

class _SelfDestructSheetState extends State<_SelfDestructSheet> {
  late DateTime? _date;
  late bool _onRead;
  late bool _hasSettings;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _onRead = widget.initialOnRead;
    _hasSettings = widget.initialDate != null || widget.initialOnRead;
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return NotelySheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: notely.text2),
              const SizedBox(width: 12),
              Text(
                'Self-destruct settings',
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
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: notely.text2),
            title: const Text('Timed destruction'),
            subtitle: Text(
              _date != null
                  ? '${_date!.month}/${_date!.day}/${_date!.year} ${_date!.hour.toString().padLeft(2, '0')}:${_date!.minute.toString().padLeft(2, '0')}'
                  : 'Not set',
            ),
            trailing: FilledButton.tonal(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now().add(const Duration(hours: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                    _date ?? DateTime.now().add(const Duration(hours: 1)),
                  ),
                );
                if (time == null || !mounted) return;
                setState(() {
                  _date = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              },
              child: const Text('Pick'),
            ),
          ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.visibility_off_outlined, color: notely.text2),
            title: const Text('Delete after first read'),
            subtitle: const Text('Note disappears once opened'),
            value: _onRead,
            onChanged: (value) {
              setState(() => _onRead = value);
            },
          ),
          if (_hasSettings) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(<String, dynamic>{
                    'date': null,
                    'onRead': false,
                  });
                },
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove self-destruct'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(<String, dynamic>{
                  'date': _date,
                  'onRead': _onRead,
                });
              },
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends ConsumerStatefulWidget {
  final List<String> collaborators;
  final TextEditingController emailController;
  final Future<String> Function(String email) onAddCollaborator;
  final Future<void> Function(String collaboratorUid) onRemoveCollaborator;

  const _ShareSheet({
    required this.collaborators,
    required this.emailController,
    required this.onAddCollaborator,
    required this.onRemoveCollaborator,
  });

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  late List<String> _collaborators;
  bool _isAdding = false;
  String? _error;
  final Map<String, String> _emails = {};

  @override
  void initState() {
    super.initState();
    _collaborators = List.of(widget.collaborators);
    _loadEmails();
  }

  Future<void> _loadEmails() async {
    final emails = <String, String>{};
    for (final uid in _collaborators) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          emails[uid] = doc.data()?['email'] as String? ?? uid;
        } else {
          emails[uid] = uid;
        }
      } catch (_) {
        emails[uid] = uid;
      }
    }
    if (!mounted) return;
    setState(() => _emails.addAll(emails));
  }

  Future<void> _submit() async {
    final email = widget.emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isAdding = true;
      _error = null;
    });
    try {
      final collaboratorUid = await widget.onAddCollaborator(email);
      if (!mounted) return;
      widget.emailController.clear();
      setState(() {
        if (collaboratorUid.isNotEmpty) {
          _collaborators = [..._collaborators, collaboratorUid];
          _emails[collaboratorUid] = email;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _remove(String collaboratorUid) async {
    setState(() {
      _error = null;
      _isAdding = true;
    });
    try {
      await widget.onRemoveCollaborator(collaboratorUid);
      if (!mounted) return;
      setState(() {
        _collaborators =
            _collaborators.where((uid) => uid != collaboratorUid).toList();
        _emails.remove(collaboratorUid);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  void dispose() {
    widget.emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return NotelySheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_add_outlined, color: notely.text2),
              const SizedBox(width: 12),
              Text(
                'Share note',
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
          Text(
            'Shared',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF86E7C8),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.emailController,
                  enabled: !_isAdding,
                  decoration: const InputDecoration(
                    hintText: 'Add people by email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isAdding ? null : _submit,
                icon: _isAdding
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          if (_collaborators.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No collaborators yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: notely.text3,
                      ),
                ),
              ),
            )
          else
            ..._collaborators.map(
              (uid) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: notely.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: notely.text3, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _emails[uid] ?? uid,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: notely.text2,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isAdding ? null : () => _remove(uid),
                      icon: const Icon(Icons.person_remove_outlined, size: 16),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
