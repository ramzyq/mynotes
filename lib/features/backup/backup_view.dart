import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/theme/widgets/async_states.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/backup/backup_service.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(crypto: ref.watch(cryptoServiceProvider)),
);

/// Export every note to one password-protected file, or bring one back.
class BackupView extends ConsumerStatefulWidget {
  final AuthUser authUser;
  const BackupView({super.key, required this.authUser});

  @override
  ConsumerState<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends ConsumerState<BackupView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _exporting = false;
  bool _importing = false;
  String? _exportError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _export() async {
    final password = _password.text;
    if (password.length < BackupService.minPasswordLength) {
      setState(() => _exportError = 'Use at least ${BackupService.minPasswordLength} characters');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _exportError = "The passwords don't match");
      return;
    }
    setState(() {
      _exportError = null;
      _exporting = true;
    });
    try {
      // Wait for the real list rather than exporting an empty one.
      final all = await ref.read(notesProvider(widget.authUser.uid).future);
      final notes = BackupService.exportable(all);
      final contents = await ref.read(backupServiceProvider).encode(notes, password);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${BackupService.fileName(DateTime.now())}');
      await file.writeAsString(contents, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Notely backup',
      ));
      _password.clear();
      _confirm.clear();
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) _snack(error is BackupException ? error.message : "Couldn't create the backup.");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a Notely backup');
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final password = await _askPassword();
    if (password == null || !mounted) return;

    setState(() => _importing = true);
    try {
      final notes = await ref.read(backupServiceProvider).decode(utf8.decode(bytes), password);
      final service = ref.read(notesServiceProvider);
      for (final n in notes) {
        final created = await service.createNote(
          uid: widget.authUser.uid,
          title: n.title,
          content: n.content,
          colorIndex: n.colorIndex,
          isPinned: n.isPinned,
          isStudyMaterial: n.isStudyMaterial,
          latitude: n.latitude,
          longitude: n.longitude,
          placeName: n.placeName,
          tags: n.tags,
          reminderAt: n.reminderAt,
          createdAt: n.createdAt,
        );
        if (n.isArchived) await service.setArchived(uid: widget.authUser.uid, note: created, archived: true);
      }
      if (mounted) _snack('Imported ${notes.length} ${notes.length == 1 ? 'note' : 'notes'}');
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) _snack(error is BackupException ? error.message : "Couldn't import this backup.");
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup password'),
        content: NotelyPasswordField(
          controller: controller,
          label: 'Password',
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          autofillHints: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: NotelyTheme.of(context).text2),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Import')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final notesAsync = ref.watch(notesProvider(widget.authUser.uid));
    // Until the notes have loaded, the counts below would read "0 notes":
    // say what's actually happening, and keep export disabled.
    final loaded = notesAsync.hasValue;
    final all = notesAsync.valueOrNull ?? const [];
    final exportable = BackupService.exportable(all).length;
    final skipped = all.where((n) => !n.isTrashed && !n.isExpired && n.sharedBy == null).length - exportable;
    final caption = TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2);

    return NotelyPage(
      title: 'Backup',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const NotelyHeading(
            title: 'Keep a copy',
            subtitle: 'A backup is one file with all your notes, encrypted with a password you choose here. '
                'Store it anywhere; nobody can read it without that password, including us.',
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Export',
            children: [
              if (!loaded && notesAsync.hasError)
                InlineErrorBanner(
                  message: "Couldn't load your notes, so there's nothing to export yet.",
                  onRetry: () => ref.invalidate(notesProvider(widget.authUser.uid)),
                )
              else if (!loaded)
                Text('Loading your notes…', style: caption)
              else
                Text(
                  '$exportable ${exportable == 1 ? 'note' : 'notes'} will be included.'
                  '${skipped > 0 ? ' $skipped PIN-locked or undecryptable ${skipped == 1 ? 'note is' : 'notes are'} left out.' : ''}',
                  style: caption,
                ),
              const SizedBox(height: 16),
              NotelyPasswordField(
                controller: _password,
                label: 'Backup password',
                enabled: !_exporting,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 12),
              NotelyPasswordField(
                controller: _confirm,
                label: 'Confirm password',
                enabled: !_exporting,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _export(),
                autofillHints: const [AutofillHints.newPassword],
              ),
              if (_exportError != null) ...[
                const SizedBox(height: 8),
                Text(_exportError!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.danger)),
              ],
              const SizedBox(height: 8),
              Text('If you forget this password, the backup cannot be opened.', style: caption),
              const SizedBox(height: 16),
              NotelyPrimaryButton(
                label: loaded ? 'Export $exportable ${exportable == 1 ? 'note' : 'notes'}' : 'Export',
                icon: Icons.ios_share,
                loading: _exporting,
                onPressed: !loaded || exportable == 0 ? null : _export,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Import',
            children: [
              Text(
                'Adds the notes from a backup file as new notes. Nothing you already have is changed.',
                style: caption,
              ),
              const SizedBox(height: 16),
              _importing
                  ? const NotelyPrimaryButton(label: 'Importing', loading: true, onPressed: null)
                  : NotelySecondaryButton(
                      label: 'Choose a backup file',
                      leading: Icon(Icons.file_open_outlined, size: 18, color: notely.text2),
                      onPressed: _import,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: notely.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notely.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
