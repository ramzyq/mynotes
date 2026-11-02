import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
import 'package:mynotes/core/theme/widgets/tag_pill.dart';
import 'package:mynotes/features/capture/providers/capture_providers.dart';

import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/notes/data/comment.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/version_history_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/self_destruct_sheet.dart';
import 'package:mynotes/features/notes/presentation/widgets/share_sheet.dart';
import 'package:mynotes/features/notes/presentation/widgets/tags_sheet.dart';
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
  /// Latest known state of the note. Updated after lock/share operations so
  /// later actions never act on the stale copy the editor was opened with.
  Note? _note;
  late final NotesService _notesService;
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
    _notesService = ref.read(notesServiceProvider);
    _note = widget.note;
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
    _placeName = note?.placeName;
    _collaborators = note?.collaborators ?? [];
    _tags = note?.tags ?? [];

    _contentController.addListener(_onContentChanged);

    if (note != null) {
      _loadBacklinks();
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

  /// Owner of the note being edited (the current user for new notes).
  String get _ownerUid => _note?.ownerUid ?? widget.authUser.uid;

  bool get _isOwner => _ownerUid == widget.authUser.uid;

  /// Collaborators can read and comment but not edit; undecryptable notes
  /// must never be saved (that would overwrite them with empty content).
  bool get _canEdit => _isOwner && !(_note?.decryptionFailed ?? false);

  /// A read-once note is deleted when the owner closes it after reading.
  bool get _destroysOnClose =>
      _isOwner && (widget.note?.selfDestructOnRead ?? false);

  @override
  void dispose() {
    final note = widget.note;
    if (note != null) {
      if (_destroysOnClose) {
        _notesService
            .deleteNote(uid: widget.authUser.uid, noteId: note.id)
            .catchError(AppErrorHandler().handle);
      }
      // Forget the key of a PIN-locked note once it is closed.
      _notesService.relock(note.id);
    }
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_canEdit) return;
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
          placeName: _placeName,
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
          note: _note!.copyWith(
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
            placeName: _placeName,
            tags: _tags,
          ),
        );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is NoteException
                ? error.message
                : 'Could not save note. Please try again.'),
          ),
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
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete note. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<String?> _askForPin() async {
    final pinController = TextEditingController();
    final pin = await showNotelyDialog<String>(
      context: context,
      title: 'Set a PIN',
      message: null,
      content: TextField(
        controller: pinController,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'At least 4 digits',
          helperText: 'The PIN encrypts this note. It cannot be recovered.',
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
    pinController.dispose();
    return pin;
  }

  Future<void> _toggleLock() async {
    final note = _note;
    if (note == null || !_isOwner) return;
    final service = ref.read(notesServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (note.isLocked) {
        await service.removeLock(uid: widget.authUser.uid, note: note);
        if (!mounted) return;
        setState(() => _note = note.copyWith(
              isLocked: false,
              pinWrappedKey: null,
              pinHash: null,
              pinSalt: null,
            ));
        return;
      }

      final canBio = await ref.read(lockServiceProvider).canUseBiometrics();
      if (!mounted) return;
      final method = canBio
          ? await showNotelyDialog<String>(
              context: context,
              title: 'Lock note',
              message: 'A PIN encrypts the note so it cannot be opened without '
                  'the PIN. Biometrics only hide it on this device.',
              actions: [
                NotelyDialogAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop(null)),
                NotelyDialogAction(label: 'Biometrics', onPressed: () => Navigator.of(context).pop('bio')),
                NotelyDialogAction(label: 'PIN', isPrimary: true, onPressed: () => Navigator.of(context).pop('pin')),
              ],
            )
          : 'pin';
      if (method == null || !mounted) return;

      if (method == 'bio') {
        await service.lockWithBiometrics(uid: widget.authUser.uid, note: note);
        if (!mounted) return;
        setState(() => _note = note.copyWith(isLocked: true));
        return;
      }

      final pin = await _askForPin();
      if (pin == null || !mounted) return;
      if (pin.length < 4) {
        messenger.showSnackBar(const SnackBar(content: Text('Use a PIN of at least 4 digits.')));
        return;
      }
      await service.lockWithPin(uid: widget.authUser.uid, note: note, pin: pin);
      if (!mounted) return;
      // Keep the note marked as PIN-locked so unlocking re-wraps the key.
      setState(() => _note = note.copyWith(isLocked: true, pinWrappedKey: 'pending'));
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      messenger.showSnackBar(SnackBar(
        content: Text(error is NoteException ? error.message : 'Could not change the lock.'),
      ));
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
        child: SelfDestructSheet(
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
        child: TagsSheet(
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
    if (_note == null) return false;
    return _collaborators.isNotEmpty || _note!.sharedBy != null || !_isOwner;
  }

  Future<void> _showShareSheet() async {
    final note = _note;
    if (note == null || !_isOwner) return;

    final emailController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: ShareSheet(
        collaborators: List.of(_collaborators),
        emailController: emailController,
        onAddCollaborator: (email) async {
          final collaboratorUid = await ref.read(shareServiceProvider).shareNote(
                uid: widget.authUser.uid,
                note: note,
                collaboratorEmail: email,
              );
          if (mounted) {
            setState(() => _collaborators = [..._collaborators, collaboratorUid]);
          }
          messenger.showSnackBar(
            const SnackBar(content: Text('Note shared')),
          );
          return collaboratorUid;
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
        onCreateLink: (mode) {
          final shareService = ref.read(shareServiceProvider);
          return shareService.createShareLink(
            uid: widget.authUser.uid,
            note: note,
            mode: mode,
          );
        },
        onRevokeLink: (token) {
          return ref.read(shareServiceProvider).revokeShareLink(token: token);
        },
      ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _addComment(String content) async {
    final note = _note;
    if (note == null) return;

    setState(() => _isAddingComment = true);
    try {
      await ref.read(notesServiceProvider).addComment(
            noteOwnerId: _ownerUid,
            noteId: note.id,
            authorUid: widget.authUser.uid,
            authorName: widget.authUser.displayName ?? widget.authUser.email.split('@').first,
            content: content,
          );
      if (!mounted) return;
      _commentController.clear();
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post comment. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final note = _note;
    if (note == null) return;

    try {
      await ref.read(notesServiceProvider).deleteComment(
            noteOwnerId: _ownerUid,
            noteId: note.id,
            commentId: commentId,
            authorUid: widget.authUser.uid,
          );
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete comment.')),
        );
      }
    }
  }

  static const List<String> _reportReasons = [
    'Spam or misleading',
    'Harassment',
    'Hate speech',
    'Inappropriate content',
    'Something else',
  ];

  Future<void> _reportComment(Comment comment) async {
    final note = _note;
    if (note == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report comment'),
        children: [
          for (final option in _reportReasons)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(option),
              ),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await ref.read(notesServiceProvider).reportComment(
            noteOwnerId: _ownerUid,
            noteId: note.id,
            commentId: comment.id,
            commentAuthorUid: comment.authorUid,
            reporterUid: widget.authUser.uid,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Report submitted. Thank you for helping keep Notely safe.'),
        ),
      );
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the report. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
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
            note == null ? 'New note' : (_canEdit ? 'Edit note' : 'View note'),
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
                  if (note != null && _isOwner) ...[
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
                      if (_destroysOnClose)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Read once: this note is permanently deleted when you close it.',
                            style: TextStyle(color: Colors.redAccent.shade200, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (note?.decryptionFailed ?? false)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            "This note can't be decrypted on this device, so it can't be edited.",
                            style: TextStyle(color: notely.text3),
                          ),
                        ),
                      TextField(
                        controller: _titleController,
                        enabled: !_isSaving,
                        readOnly: !_canEdit,
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
                          readOnly: !_canEdit,
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
                    onPressed: _isSaving || !_canEdit ? null : _saveNote,
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
                          (noteOwnerId: _ownerUid, noteId: note.id, viewerUid: widget.authUser.uid),
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
                        (noteOwnerId: _ownerUid, noteId: note.id, viewerUid: widget.authUser.uid),
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
                                          if (comment.authorUid != widget.authUser.uid)
                                            IconButton(
                                              icon: Icon(Icons.flag_outlined, size: 16, color: notely.text4),
                                              visualDensity: VisualDensity.compact,
                                              tooltip: 'Report comment',
                                              onPressed: () => _reportComment(comment),
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
                                        comment.displayContent,
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
