import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/core/theme/note_palette.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
import 'package:mynotes/features/capture/providers/capture_providers.dart';
import 'package:mynotes/features/capture/services/capture_exception.dart';
import 'package:mynotes/features/capture/services/voice_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/notes/data/comment.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/version_history_view.dart';
import 'package:mynotes/features/notes/presentation/widgets/self_destruct_sheet.dart';
import 'package:mynotes/features/notes/presentation/widgets/share_sheet.dart';
import 'package:mynotes/features/notes/presentation/widgets/tags_sheet.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/core/format/dates.dart';
import 'package:mynotes/features/notes/presentation/widgets/checklist_text.dart';
import 'package:mynotes/features/reminders/reminder_providers.dart';

class NoteEditorView extends ConsumerStatefulWidget {
  final AuthUser authUser;
  final Note? note;

  /// Text to start a new note with (quick capture / share into Notely).
  final String? initialContent;

  const NoteEditorView({
    super.key,
    required this.authUser,
    this.note,
    this.initialContent,
  });

  @override
  ConsumerState<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends ConsumerState<NoteEditorView>
    with WidgetsBindingObserver {
  /// Latest known state of the note. Updated after lock/share operations so
  /// later actions never act on the stale copy the editor was opened with.
  Note? _note;
  late final NotesService _notesService;
  late final TextEditingController _titleController;
  late final NoteBodyController _contentController;
  DateTime? _reminderAt;
  late int _selectedColorIndex;
  late bool _isPinned;
  late bool _isStudyMaterial;
  late bool _selfDestructOnRead;
  DateTime? _selfDestructAt;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isRecording = false;

  /// Starting or stopping a recording is in progress; taps are ignored.
  bool _voiceBusy = false;
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

  /// Autosave: edits are written [_autosaveDelay] after typing stops, and
  /// any remaining changes are written when the editor is closed.
  static const _autosaveDelay = Duration(milliseconds: 1500);
  Timer? _autosaveTimer;
  Future<bool>? _saveInFlight;
  late String _savedFingerprint;
  final ValueNotifier<_SaveStatus> _saveStatus = ValueNotifier(_SaveStatus.clean);

  @override
  void initState() {
    super.initState();
    _notesService = ref.read(notesServiceProvider);
    _note = widget.note;
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = NoteBodyController(text: note?.content ?? widget.initialContent ?? '');
    _reminderAt = note?.reminderAt;
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
    _savedFingerprint = _fingerprint();
    if (note == null && (widget.initialContent?.trim().isNotEmpty ?? false)) {
      _savedFingerprint = '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutosave());
    }
    _titleController.addListener(_scheduleAutosave);
    _contentController.addListener(_scheduleAutosave);

    if (note != null) {
      _loadBacklinks();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  /// The OS may kill a backgrounded app without warning, so pending edits
  /// are written as soon as the app leaves the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_isDirty) _persist(quiet: true);
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
    final int endIdx = closeIdx != -1 ? closeIdx + 2 : cursorPos;
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Scan text', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Text is read from the photo on this device and added to your note. The photo is not uploaded.',
                style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2),
              ),
              const SizedBox(height: 20),
              NotelyPrimaryButton(
                label: 'Take a photo',
                icon: Icons.photo_camera_outlined,
                onPressed: () => Navigator.of(context).pop('camera'),
              ),
              const SizedBox(height: 12),
              NotelySecondaryButton(
                label: 'Choose from photos',
                leading: Icon(Icons.photo_library_outlined, size: 18, color: notely.text2),
                onPressed: () => Navigator.of(context).pop('gallery'),
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
      if (text == null || !mounted) return; // Cancelled.
      if (text.isEmpty) {
        _showCaptureError(const CaptureUnavailableException(
          "No text found in that photo. Try a sharper, well-lit shot.",
        ));
        return;
      }

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
    } on CaptureUnavailableException catch (e) {
      _showCaptureError(e);
    } catch (error, stack) {
      // Anything unexpected (e.g. a missing plugin) still gets a message.
      AppErrorHandler().handle(error, stack);
      _showCaptureError(const CaptureUnavailableException("Couldn't scan that photo."));
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
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _placeName = result.placeName;
      });
    } on CaptureUnavailableException catch (e) {
      _showCaptureError(e);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      _showCaptureError(const CaptureUnavailableException("Couldn't get your location."));
    } finally {
      if (mounted) {
        setState(() => _isCapturingLocation = false);
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_voiceBusy) return;
    final voiceService = ref.read(voiceServiceProvider);
    setState(() => _voiceBusy = true);
    try {
      await voiceService.requestPermission();
      await voiceService.startRecording();
      // "Recording" (and the stop button) only once it really is.
      if (mounted) setState(() => _isRecording = true);
    } on CaptureUnavailableException catch (e) {
      _showCaptureError(e);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      _showCaptureError(const CaptureUnavailableException("Couldn't start recording."));
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  void _showCaptureError(CaptureUnavailableException e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(e.message),
      action: e.needsSettings
          ? SnackBarAction(label: 'Settings', onPressed: () => openAppSettings())
          : null,
    ));
  }

  Future<void> _stopVoiceRecording() async {
    if (_voiceBusy) return;
    final voiceService = ref.read(voiceServiceProvider);
    setState(() => _voiceBusy = true);
    final VoiceResult? result;
    try {
      result = await voiceService.stopRecordingAndTranscribe();
    } catch (error, stack) {
      // Never leave the editor stuck in "recording".
      AppErrorHandler().handle(error, stack);
      if (mounted) setState(() => _isRecording = false);
      _showCaptureError(const CaptureUnavailableException("Couldn't save the recording."));
      return;
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
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

    // setState so autosave sees the new attachment.
    setState(() => _audioAttachments = [..._audioAttachments, filePath]);
    if (transcription.isEmpty) {
      _showCaptureError(const CaptureUnavailableException(
        "Recording saved. Couldn't turn it into text, so nothing was added to the note.",
      ));
    }
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
    WidgetsBinding.instance.removeObserver(this);
    // Removed without going through _close (sign-out, a replaced route...):
    // write what the autosave timer would have written. Best effort, as
    // nothing is left on screen to report a failure to.
    if (_autosaveTimer?.isActive ?? false) _persist(quiet: true);
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
    _autosaveTimer?.cancel();
    _saveStatus.dispose();
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// Everything the save writes, so "unsaved changes" is an exact comparison.
  String _fingerprint() => [
    _titleController.text.trim(),
    _contentController.text.trim(),
    _selectedColorIndex,
    _isPinned,
    _isStudyMaterial,
    _selfDestructAt?.toIso8601String(),
    _selfDestructOnRead,
    _audioAttachments.join('\u0000'),
    _latitude,
    _longitude,
    _placeName,
    _tags.join('\u0000'),
    _reminderAt?.toIso8601String(),
  ].join('\u0001');

  bool get _isDirty => _fingerprint() != _savedFingerprint;

  /// A new note with no title and no body is not worth creating.
  bool get _isBlankDraft =>
      _note == null &&
      _titleController.text.trim().isEmpty &&
      _contentController.text.trim().isEmpty;

  /// Read-once notes are deleted on close, so there is nothing to keep.
  bool get _shouldPersist => _canEdit && !_destroysOnClose && !_deleted;

  /// Set while the note is being deleted so nothing writes it back.
  bool _deleted = false;

  /// Every state change in this editor may touch a saved field (color, pin,
  /// tags, location...), so each one re-checks for unsaved changes.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (!_shouldPersist) return;
    _autosaveTimer?.cancel();
    if (!_isDirty) {
      if (_saveStatus.value == _SaveStatus.edited) {
        _saveStatus.value = _SaveStatus.clean;
      }
      return;
    }
    _saveStatus.value = _SaveStatus.edited;
    _autosaveTimer = Timer(_autosaveDelay, () => _persist(quiet: true));
  }

  /// Write pending changes. Returns true when nothing is left unsaved.
  /// Concurrent calls share one write, then re-check for newer edits.
  Future<bool> _persist({bool quiet = false}) async {
    _autosaveTimer?.cancel();
    if (!_shouldPersist) return true;
    final inFlight = _saveInFlight;
    if (inFlight != null) {
      await inFlight;
      if (!mounted) return false;
    }
    if (!_isDirty || _isBlankDraft) return true;
    final write = _write(quiet: quiet);
    _saveInFlight = write;
    try {
      return await write;
    } finally {
      if (identical(_saveInFlight, write)) _saveInFlight = null;
    }
  }

  Future<bool> _write({required bool quiet}) async {
    final fingerprint = _fingerprint();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final storedTitle = title.isEmpty && content.isEmpty
        ? 'Untitled note'
        : title;
    _saveStatus.value = _SaveStatus.saving;
    try {
      final current = _note;
      if (current == null) {
        // _notesService, not ref: this also runs after dispose.
        final created = await _notesService.createNote(
              uid: widget.authUser.uid,
              title: storedTitle,
              content: content,
              colorIndex: _selectedColorIndex,
              isPinned: _isPinned,
              isStudyMaterial: _isStudyMaterial,
              audioAttachments: _audioAttachments,
              latitude: _latitude,
              longitude: _longitude,
              placeName: _placeName,
              tags: _tags,
              reminderAt: _reminderAt,
              selfDestructAt: _selfDestructAt,
              selfDestructOnRead: _selfDestructOnRead,
            );
        // Later saves update this note instead of creating another one.
        if (mounted) {
          setState(() => _note = created);
        } else {
          _note = created;
        }
      } else {
        final updated = current.copyWith(
          title: storedTitle,
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
          reminderAt: _reminderAt,
        );
        await _notesService.updateNote(uid: widget.authUser.uid, note: updated);
        _note = updated;
      }
      _savedFingerprint = fingerprint;
      if (mounted) {
        _saveStatus.value = _isDirty ? _SaveStatus.edited : _SaveStatus.saved;
        // Typing during the write: save the newer text too.
        if (_isDirty) _scheduleAutosave();
      }
      return !_isDirty;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        _saveStatus.value = _SaveStatus.failed;
        if (!quiet) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is NoteException
                    ? error.message
                    : 'Could not save note. Please try again.',
              ),
            ),
          );
        }
      }
      return false;
    }
  }

  /// Back button, system back and the Done button all close through here.
  Future<void> _close([Object? result]) async {
    if (await _persist()) {
      if (mounted) Navigator.of(context).pop(result);
      return;
    }
    if (!mounted) return;
    final discard = await showNotelyDialog<bool>(
      context: context,
      title: 'Discard changes?',
      message: "Your latest changes couldn't be saved.",
      actions: [
        NotelyDialogAction(
          label: 'Keep editing',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        NotelyDialogAction(
          label: 'Discard',
          isDestructive: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (discard == true && mounted) Navigator.of(context).pop(result);
  }

  Future<void> _saveNote() async {
    if (!_canEdit) return;
    setState(() => _isSaving = true);
    try {
      await _close(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Move the note to the trash (after saving pending edits) and close.
  /// The snackbar offers Undo; the note stays restorable from Trash.
  Future<void> _deleteNote() async {
    if (_note == null) await _persist(quiet: true);
    // _note, not widget.note: a new note may already exist from autosave.
    final note = _note;
    if (note == null || !mounted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(notesServiceProvider);
    final uid = widget.authUser.uid;
    try {
      await _persist(quiet: true);
      _autosaveTimer?.cancel();
      _deleted = true;
      await service.moveToTrash(uid: uid, notes: [note]);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(
        content: const Text('Moved to trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => service.restoreFromTrash(uid: uid, notes: [note]).catchError(AppErrorHandler().handle),
        ),
      ));
    } catch (error, stack) {
      _deleted = false;
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't move the note to the trash.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// Quick choices for a reminder, then a date and time picker.
  Future<void> _showReminderSheet() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final laterToday = now.hour < 17
        ? today.add(const Duration(hours: 18))
        : DateTime(now.year, now.month, now.day, now.hour + 3);
    final tomorrow = today.add(const Duration(days: 1, hours: 9));
    final nextWeek = today.add(Duration(days: 8 - now.weekday, hours: 9)); // next Monday

    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) {
        final notely = NotelyTheme.of(context);
        Widget option(String label, DateTime? at, Object value, {IconData? icon, Color? color}) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(icon ?? Icons.schedule, size: 20, color: color ?? notely.text2),
              title: Text(label, style: TextStyle(fontFamily: 'Geist', fontSize: 15, color: color ?? notely.text)),
              trailing: at == null
                  ? null
                  : Text(formatDateTime(at), style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3)),
              onTap: () => Navigator.of(context).pop(value),
            );
        return NotelySheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Remind me', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              option(now.hour < 17 ? 'This evening' : 'Later today', laterToday, laterToday),
              option('Tomorrow morning', tomorrow, tomorrow),
              option('Next week', nextWeek, nextWeek),
              option('Pick a date and time', null, 'pick', icon: Icons.calendar_today_outlined),
              if (_reminderAt != null)
                option('Remove reminder', null, 'remove', icon: Icons.notifications_off_outlined, color: notely.danger),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    DateTime? at;
    if (choice == 'remove') {
      setState(() => _reminderAt = null);
      return;
    } else if (choice == 'pick') {
      final initial = _reminderAt ?? tomorrow;
      final date = await showDatePicker(
        context: context,
        initialDate: initial.isBefore(today) ? today : initial,
        firstDate: today,
        lastDate: today.add(const Duration(days: 365 * 5)),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
      if (time == null || !mounted) return;
      at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (!at.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a time in the future.')));
        return;
      }
    } else {
      at = choice as DateTime;
    }

    setState(() => _reminderAt = at);
    final allowed = await ref.read(reminderServiceProvider).requestPermission();
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Notifications are off for Notely, so this reminder will not alert you.'),
        action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings()),
      ));
    }
  }

  Future<String?> _askForPin() async {
    // The field owns its controller: disposing one here would break the
    // dialog's closing animation, which still draws the field.
    var pin = '';
    return showNotelyDialog<String>(
      context: context,
      title: 'Set a PIN',
      message: null,
      content: _PinField(onChanged: (value) => pin = value),
      actions: [
        NotelyDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(null),
        ),
        NotelyDialogAction(
          label: 'Set PIN',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(pin),
        ),
      ],
    );
  }

  /// Ask for a PIN, encrypt the note under it, and offer biometric unlock.
  Future<void> _lockWithPin() async {
    final note = _note;
    if (note == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final pin = await _askForPin();
    if (pin == null || !mounted) return;
    if (pin.length < NotesService.minPinLength) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Use a PIN of at least ${NotesService.minPinLength} digits.')),
      );
      return;
    }
    final uid = widget.authUser.uid;
    final biometrics = ref.read(biometricUnlockServiceProvider);
    // A new PIN means a new PIN-derived key; any old biometric entry is stale.
    await biometrics.disable(uid, note.id);
    await ref.read(notesServiceProvider).lockWithPin(uid: uid, note: note, pin: pin);
    if (!mounted) return;
    // Mark as PIN-locked locally; the real wrapped key is on the server and
    // the unlocked key stays cached until the editor closes.
    setState(() => _note = note.copyWith(isLocked: true, pinWrappedKey: 'pending', pinHash: null));

    if (!await biometrics.isSupported() || !mounted) return;
    final useBiometrics = await showNotelyDialog<bool>(
      context: context,
      title: 'Unlock with biometrics?',
      message: 'Open this note with Face ID, Touch ID, or your fingerprint on '
          'this device. Your PIN keeps working and is needed on other devices.',
      actions: [
        NotelyDialogAction(label: 'Not now', onPressed: () => Navigator.of(context).pop(false)),
        NotelyDialogAction(label: 'Turn on', isPrimary: true, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (useBiometrics == true) await _setBiometric(true);
  }

  Future<void> _setBiometric(bool enabled) async {
    final note = _note;
    if (note == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final biometrics = ref.read(biometricUnlockServiceProvider);
    if (!enabled) {
      await biometrics.disable(widget.authUser.uid, note.id);
      messenger.showSnackBar(const SnackBar(content: Text('Biometric unlock turned off on this device.')));
      return;
    }
    final ok = await biometrics.enable(widget.authUser.uid, note.id);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Biometric unlock turned on for this device.'
          : "Couldn't turn on biometric unlock. Your PIN still works."),
    ));
  }

  Future<void> _toggleLock() async {
    final note = _note;
    if (note == null || !_isOwner) return;
    final service = ref.read(notesServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final uid = widget.authUser.uid;

    try {
      if (!note.isLocked) {
        await _lockWithPin();
        return;
      }

      final biometrics = ref.read(biometricUnlockServiceProvider);
      final pinLocked = note.hasPinLock;
      final supported = pinLocked && await biometrics.isSupported();
      final enabled = supported && await biometrics.isEnabled(uid, note.id);
      if (!mounted) return;

      final choice = await showNotelyDialog<String>(
        context: context,
        title: 'Locked note',
        message: pinLocked
            ? 'This note is encrypted with your PIN.'
            : 'This note is only hidden on this device. Set a PIN to encrypt it.',
        actions: [
          NotelyDialogAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop(null)),
          NotelyDialogAction(label: 'Remove lock', isDestructive: true, onPressed: () => Navigator.of(context).pop('remove')),
          if (!pinLocked)
            NotelyDialogAction(label: 'Set PIN', isPrimary: true, onPressed: () => Navigator.of(context).pop('pin')),
          if (supported)
            NotelyDialogAction(
              label: enabled ? 'Turn off biometrics' : 'Use biometrics',
              isPrimary: true,
              onPressed: () => Navigator.of(context).pop(enabled ? 'bio-off' : 'bio-on'),
            ),
        ],
      );
      if (choice == null || !mounted) return;

      switch (choice) {
        case 'remove':
          await service.removeLock(uid: uid, note: note);
          await biometrics.disable(uid, note.id);
          if (!mounted) return;
          setState(() => _note = note.copyWith(
                isLocked: false,
                pinWrappedKey: null,
                pinHash: null,
                pinSalt: null,
              ));
        case 'pin':
          await service.removeLock(uid: uid, note: note);
          if (!mounted) return;
          setState(() => _note = note.copyWith(isLocked: false));
          await _lockWithPin();
        case 'bio-on':
          await _setBiometric(true);
        case 'bio-off':
          await _setBiometric(false);
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      messenger.showSnackBar(SnackBar(
        content: Text(error is NoteException ? error.message : 'Could not change the lock.'),
      ));
    }
  }

  Future<void> _showSelfDestructSheet() async {
    final DateTime? pickedDate = _selfDestructAt;
    final bool onRead = _selfDestructOnRead;

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

  Future<void> _showColorSheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        final notely = NotelyTheme.of(context);
        return NotelySheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Color label', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Shown as the margin line on this note.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < kNotePalette.length; i++)
                    Semantics(
                      button: true,
                      selected: i == _selectedColorIndex,
                      label: kNotePaletteNames[i],
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(i),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          child: Column(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: kNotePalette[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: i == _selectedColorIndex ? notely.text : Colors.transparent,
                                  width: 2,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                ),
                              ),
                              child: i == _selectedColorIndex ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                            ),
                            const SizedBox(height: 6),
                            Text(kNotePaletteNames[i], style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: notely.text2)),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _selectedColorIndex = picked);
  }

  String _selfDestructLabel() {
    final at = _selfDestructAt;
    if (at == null) return 'Deletes after reading';
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return 'Deletes ${at.month}/${at.day}/${at.year} $hh:$mm';
  }

  void _openVersionHistory(Note note) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => VersionHistoryView(authUser: widget.authUser, noteId: note.id),
    ));
  }

  Future<void> _onMenu(String value) async {
    final note = _note;
    switch (value) {
      case 'study':
        setState(() => _isStudyMaterial = !_isStudyMaterial);
      case 'lock':
        await _toggleLock();
      case 'destruct':
        await _showSelfDestructSheet();
      case 'history':
        if (note != null) _openVersionHistory(note);
      case 'remind':
        await _showReminderSheet();
      case 'delete':
        await _deleteNote();
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final notely = NotelyTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final accent = kNotePalette[_selectedColorIndex % kNotePalette.length];
    final busy = _isSaving || _isDeleting;
    final hasSelfDestruct = _selfDestructAt != null || _selfDestructOnRead;

    return PopScope<Object?>(
      // Editable notes close through _close so pending edits are saved first.
      canPop: !_shouldPersist,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close(result);
      },
      child: Scaffold(
        backgroundColor: notely.bg,
        appBar: AppBar(
          backgroundColor: notely.bg,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: _canEdit
              ? ValueListenableBuilder<_SaveStatus>(
                  valueListenable: _saveStatus,
                  builder: (context, status, _) => Text(
                    switch (status) {
                      _SaveStatus.clean => note == null ? 'New note' : 'Saved',
                      _SaveStatus.edited => 'Edited',
                      _SaveStatus.saving => 'Saving…',
                      _SaveStatus.saved => 'Saved',
                      _SaveStatus.failed => 'Not saved',
                    },
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 13,
                      color: status == _SaveStatus.failed ? notely.danger : notely.text3,
                    ),
                  ),
                )
              : Text('View only', style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3)),
          actions: [
            if (_isOwner)
              IconButton(
                tooltip: _isPinned ? 'Unpin' : 'Pin',
                onPressed: busy ? null : () => setState(() => _isPinned = !_isPinned),
                icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20),
              ),
            if (note != null && _isOwner)
              IconButton(
                tooltip: 'Share',
                onPressed: busy ? null : _showShareSheet,
                icon: const Icon(Icons.ios_share, size: 20),
              ),
            if (_isOwner)
              PopupMenuButton<String>(
                tooltip: 'More',
                enabled: !busy,
                icon: _isDeleting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.more_horiz),
                onSelected: _onMenu,
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(value: 'study', checked: _isStudyMaterial, child: const Text('Use as flashcard')),
                  if (note != null)
                    PopupMenuItem(value: 'lock', child: Text(note.isLocked ? 'Lock settings' : 'Lock with PIN')),
                  PopupMenuItem(value: 'destruct', child: Text(hasSelfDestruct ? 'Change self-destruct' : 'Self-destruct')),
                  PopupMenuItem(value: 'remind', child: Text(_reminderAt == null ? 'Remind me' : 'Change reminder')),
                  if (note != null) const PopupMenuItem(value: 'history', child: Text('Version history')),
                  if (note != null) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Move to trash', style: TextStyle(color: notely.danger))),
                  ],
                ],
              ),
            if (_canEdit)
              TextButton(
                onPressed: busy ? null : _saveNote,
                child: _isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Done', style: TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w500, color: notely.violet)),
              ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: _canEdit
            ? _EditorToolbar(
                enabled: !busy,
                isRecording: _isRecording,
                isCapturingLocation: _isCapturingLocation,
                hasLocation: _latitude != null,
                onScan: _showOcrSheet,
                onVoice: _isRecording ? _stopVoiceRecording : _startVoiceRecording, // Both ignore taps while _voiceBusy.
                onLocation: _captureLocation,
                onChecklist: () {
                  _contentController.toggleChecklistLine();
                  _contentFocusNode.requestFocus();
                },
              )
            : null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_destroysOnClose)
                _Notice(
                  icon: Icons.visibility_off_outlined,
                  text: 'Read once: this note is deleted when you close it.',
                  color: notely.danger,
                ),
              if (_isOwner && (note?.isLocked ?? false) && !(note?.hasPinLock ?? false))
                _Notice(
                  icon: Icons.lock_open,
                  text: 'This note is hidden but not encrypted.',
                  color: notely.text2,
                  action: TextButton(onPressed: _toggleLock, child: const Text('Encrypt with PIN')),
                ),
              if (note?.decryptionFailed ?? false)
                _Notice(
                  icon: Icons.error_outline,
                  text: "This note can't be decrypted on this device, so it can't be edited.",
                  color: notely.text2,
                ),
              // The writing surface: the margin line in the note's color, then
              // the title, one row of metadata and the body.
              Container(
                padding: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      enabled: !_isSaving,
                      readOnly: !_canEdit,
                      textCapitalization: TextCapitalization.sentences,
                      style: textTheme.displayMedium,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: textTheme.displayMedium?.copyWith(color: notely.text4),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          leading: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                          ),
                          label: kNotePaletteNames[_selectedColorIndex % kNotePaletteNames.length],
                          tooltip: 'Color label',
                          onTap: _canEdit && !busy ? _showColorSheet : null,
                        ),
                        _MetaChip(
                          leading: Icon(Icons.sell_outlined, size: 14, color: notely.text3),
                          label: _tags.isEmpty ? 'Add tags' : _tags.join(', '),
                          tooltip: 'Tags',
                          onTap: _canEdit && !busy ? _showTagsDialog : null,
                        ),
                        if (hasSelfDestruct)
                          _MetaChip(
                            leading: Icon(Icons.timer_outlined, size: 14, color: notely.danger),
                            label: _selfDestructLabel(),
                            color: notely.danger,
                            tooltip: 'Self-destruct',
                            onTap: _isOwner && !busy ? _showSelfDestructSheet : null,
                          ),
                        if (_reminderAt != null)
                          _MetaChip(
                            leading: Icon(
                              Icons.notifications_none,
                              size: 14,
                              color: _reminderAt!.isAfter(DateTime.now()) ? notely.violet : notely.text3,
                            ),
                            label: formatDateTime(_reminderAt!),
                            color: _reminderAt!.isAfter(DateTime.now()) ? notely.violet : notely.text3,
                            tooltip: 'Reminder',
                            onTap: _isOwner && !busy ? _showReminderSheet : null,
                          ),
                        if (_isStudyMaterial)
                          _MetaChip(
                            leading: Icon(Icons.style_outlined, size: 14, color: notely.text3),
                            label: 'Flashcard',
                            tooltip: 'Used in Study. Tap to stop.',
                            onTap: _isOwner && !busy ? () => setState(() => _isStudyMaterial = false) : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CompositedTransformTarget(
                      link: _suggestionLayerLink,
                      child: TextField(
                        controller: _contentController..mutedColor = notely.text3,
                        focusNode: _contentFocusNode,
                        inputFormatters: [ChecklistContinuation()],
                        onTap: () {
                          if (!_canEdit) return;
                          final sel = _contentController.selection;
                          if (sel.isValid && sel.isCollapsed) _contentController.toggleAt(sel.baseOffset);
                        },
                        enabled: !_isSaving,
                        readOnly: !_canEdit,
                        autofocus: note == null,
                        minLines: 12,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        textAlignVertical: TextAlignVertical.top,
                        style: textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Start writing. Type [[ to link a note.',
                          hintStyle: textTheme.bodyLarge?.copyWith(color: notely.text4),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_showSuggestions)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: notely.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: notely.borderStrong),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final title = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.link, size: 16, color: notely.text3),
                        title: Text(title, style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text)),
                        onTap: () => _insertSuggestion(title),
                      );
                    },
                  ),
                ),
              if (_audioAttachments.isNotEmpty) ...[
                const _SectionLabel('Recordings'),
                for (final path in _audioAttachments)
                  _RowTile(
                    icon: Icons.graphic_eq,
                    label: path.split('\\').last.split('/').last,
                  ),
              ],
              if (_latitude != null && _longitude != null) ...[
                _SectionLabel(
                  'Location',
                  trailing: _canEdit
                      ? IconButton(
                          tooltip: 'Remove location',
                          icon: Icon(Icons.close, size: 16, color: notely.text3),
                          onPressed: () => setState(() {
                            _latitude = null;
                            _longitude = null;
                            _placeName = null;
                          }),
                        )
                      : null,
                ),
                if (_placeName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_placeName!, style: textTheme.bodySmall),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 160,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_latitude!, _longitude!),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.flutter.mynotes',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_latitude!, _longitude!),
                              child: Icon(Icons.location_on, color: notely.violet, size: 32),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (note != null) ...[
                const _SectionLabel('Linked from'),
                if (_loadingBacklinks)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_backlinks.isEmpty)
                  Text('No other notes link here yet. Type [[ in any note to link one.', style: textTheme.bodySmall)
                else
                  for (final bl in _backlinks)
                    _RowTile(
                      leading: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: kNotePalette[bl.colorIndex % kNotePalette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: bl.displayTitle,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => NoteEditorView(authUser: widget.authUser, note: bl),
                      )),
                    ),
              ],
              if (_isShared && note != null) ..._buildComments(note, notely, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildComments(Note note, NotelyTheme notely, TextTheme textTheme) {
    final comments = ref.watch(
      commentsProvider((noteOwnerId: _ownerUid, noteId: note.id, viewerUid: widget.authUser.uid)),
    );
    final count = comments.valueOrNull?.length ?? 0;
    return [
      _SectionLabel(
        'Comments',
        trailing: count > 0
            ? Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: notely.text3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            : null,
      ),
      comments.when(
        data: (comments) {
          if (comments.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('No comments yet.', style: textTheme.bodySmall),
            );
          }
          return Column(
            children: [
              for (final comment in comments)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                  decoration: BoxDecoration(
                    color: notely.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: notely.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.authorName,
                              style: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500, color: notely.text),
                            ),
                          ),
                          Text(_commentTime(comment.createdAt), style: textTheme.labelSmall),
                          if (comment.authorUid != widget.authUser.uid)
                            IconButton(
                              icon: Icon(Icons.flag_outlined, size: 16, color: notely.text3),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Report comment',
                              onPressed: () => _reportComment(comment),
                            )
                          else
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 16, color: notely.text3),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Delete comment',
                              onPressed: () => _deleteComment(comment.id),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(comment.displayContent, style: textTheme.bodyMedium?.copyWith(color: notely.text2)),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Unable to load comments.', style: textTheme.bodySmall),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: notely.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: notely.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: !_isAddingComment,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Add a comment',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              onPressed: _isAddingComment || _commentController.text.trim().isEmpty
                  ? null
                  : () => _addComment(_commentController.text.trim()),
              icon: _isAddingComment
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.arrow_upward, size: 18, color: notely.violet),
            ),
          ],
        ),
      ),
    ];
  }

  String _commentTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${time.month}/${time.day}/${time.year}';
  }
}

/// Shown next to the pin and study chips so autosave is visible.
enum _SaveStatus { clean, edited, saving, saved, failed }

/// Capture tools under the writing surface, labeled so they explain
/// themselves: scan text from a photo, dictate, attach where you are.
class _EditorToolbar extends StatelessWidget {
  final bool enabled;
  final bool isRecording;
  final bool isCapturingLocation;
  final bool hasLocation;
  final VoidCallback onScan;
  final VoidCallback onVoice;
  final VoidCallback onLocation;
  final VoidCallback onChecklist;

  const _EditorToolbar({
    required this.enabled,
    required this.isRecording,
    required this.isCapturingLocation,
    required this.hasLocation,
    required this.onScan,
    required this.onVoice,
    required this.onLocation,
    required this.onChecklist,
  });

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: notely.bg,
        border: Border(top: BorderSide(color: notely.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _ToolButton(icon: Icons.checklist, label: 'List', onTap: enabled ? onChecklist : null),
              _ToolButton(icon: Icons.document_scanner_outlined, label: 'Scan', onTap: enabled ? onScan : null),
              _ToolButton(
                icon: isRecording ? Icons.stop_circle_outlined : Icons.mic_none,
                label: isRecording ? 'Stop' : 'Dictate',
                color: isRecording ? notely.danger : null,
                onTap: enabled ? onVoice : null,
              ),
              _ToolButton(
                icon: hasLocation ? Icons.location_on : Icons.location_on_outlined,
                label: 'Place',
                busy: isCapturingLocation,
                onTap: enabled && !isCapturingLocation ? onLocation : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool busy;

  const _ToolButton({required this.icon, required this.label, required this.onTap, this.color, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final fg = onTap == null && !busy ? notely.text4 : (color ?? notely.text2);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        disabledForegroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: fg)),
        ],
      ),
    );
  }
}

/// One item of the metadata row under the title: color, tags, timers.
class _MetaChip extends StatelessWidget {
  final Widget leading;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _MetaChip({required this.leading, required this.label, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: notely.border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 28,
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: color ?? notely.text2),
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

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;

  const _Notice({required this.icon, required this.text, required this.color, this.action});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.fromLTRB(12, action == null ? 12 : 4, action == null ? 12 : 4, action == null ? 12 : 4),
      decoration: BoxDecoration(
        color: notely.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: notely.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: color))),
          ?action,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const _SectionLabel(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 8),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.text2)),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback? onTap;

  const _RowTile({this.icon, this.leading, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: notely.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: notely.border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Center(child: leading ?? Icon(icon, size: 16, color: notely.text3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text),
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right, size: 18, color: notely.text3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Digits-only PIN entry for the "Set a PIN" dialog.
class _PinField extends StatefulWidget {
  const _PinField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: true,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: widget.onChanged,
      decoration: const InputDecoration(
        hintText: 'At least ${NotesService.minPinLength} digits',
        helperText: 'The PIN encrypts this note. It cannot be recovered.',
        border: OutlineInputBorder(),
      ),
    );
  }
}
