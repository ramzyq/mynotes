import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/capture/providers/capture_providers.dart';

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
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _selectedColorIndex = note?.colorIndex ?? 0;
    _isPinned = note?.isPinned ?? false;
    _selfDestructAt = note?.selfDestructAt;
    _selfDestructOnRead = note?.selfDestructOnRead ?? false;
    _audioAttachments = note?.audioAttachments ?? [];
    _latitude = note?.latitude;
    _longitude = note?.longitude;

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
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
                const Icon(Icons.text_snippet, color: Colors.white70),
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
          audioAttachments: _audioAttachments,
          latitude: _latitude,
          longitude: _longitude,
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
            selfDestructAt: _selfDestructAt,
            selfDestructOnRead: _selfDestructOnRead,
            audioAttachments: _audioAttachments,
            latitude: _latitude,
            longitude: _longitude,
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

  Future<void> _showSelfDestructSheet() async {
    final note = widget.note;
    if (note == null) return;

    DateTime? pickedDate = _selfDestructAt;
    bool onRead = _selfDestructOnRead;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SelfDestructSheet(
        initialDate: pickedDate,
        initialOnRead: onRead,
      ),
    );

    if (result != null) {
      setState(() {
        _selfDestructAt = result['date'] as DateTime?;
        _selfDestructOnRead = result['onRead'] as bool;
      });
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
          IconButton(
            icon: const Icon(Icons.document_scanner),
            onPressed: _isSaving || _isDeleting ? null : _showOcrSheet,
          ),
          IconButton(
            icon: Icon(_isRecording ? Icons.mic : Icons.mic_none),
            onPressed: _isSaving || _isDeleting
                ? null
                : _isRecording
                    ? _stopVoiceRecording
                    : _startVoiceRecording,
          ),
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
          ),
          if (note != null)
            IconButton(
              icon: Icon(note.isLocked ? Icons.lock : Icons.lock_open),
              onPressed: _isSaving || _isDeleting ? null : _toggleLock,
            ),
          if (note != null)
            IconButton(
              icon: Icon(
                _selfDestructAt != null || _selfDestructOnRead
                    ? Icons.timer
                    : Icons.timer_outlined,
              ),
              onPressed: _isSaving || _isDeleting ? null : _showSelfDestructSheet,
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
                            color: const Color(0xFF1A2340),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF27314A)),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final title = _suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.link, size: 18, color: Colors.white60),
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
                          color: const Color(0xFF141B2D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.audiotrack,
                                color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                path.split('\\').last.split('/').last,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
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
                      const Icon(Icons.location_on, color: Colors.white70, size: 20),
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
                              color: Colors.white60,
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
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
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
                      const Icon(Icons.link, color: Colors.white70, size: 20),
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
                            color: Colors.white54,
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
                            color: const Color(0xFF141B2D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF27314A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _palette[bl.colorIndex % _palette.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  bl.displayTitle,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
                const Icon(Icons.timer_outlined, color: Colors.white70),
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
              leading: const Icon(Icons.schedule, color: Colors.white70),
              title: const Text('Timed destruction'),
              subtitle: Text(
                _date != null
                    ? '${_date!.month}/${_date!.day}/${_date!.year} ${_date!.hour.toString().padLeft(2, '0')}:${_date!.minute.toString().padLeft(2, '0')}'
                    : 'Not set',
              ),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  final scaffoldContext = context;
                  final date = await showDatePicker(
                    context: scaffoldContext,
                    initialDate: _date ?? DateTime.now().add(const Duration(hours: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null || !mounted) return;
                  // ignore: use_build_context_synchronously
                  final time = await showTimePicker(
                    context: scaffoldContext,
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
              secondary: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
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
      ),
    );
  }
}
