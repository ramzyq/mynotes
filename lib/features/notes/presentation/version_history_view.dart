import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/format/dates.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

class VersionHistoryView extends ConsumerStatefulWidget {
  final AuthUser authUser;
  final String noteId;

  const VersionHistoryView({
    super.key,
    required this.authUser,
    required this.noteId,
  });

  @override
  ConsumerState<VersionHistoryView> createState() =>
      _VersionHistoryViewState();
}

class _VersionHistoryViewState extends ConsumerState<VersionHistoryView> {
  late Future<List<NoteVersion>> _versionsFuture;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  void _loadVersions() {
    _versionsFuture = ref
        .read(notesServiceProvider)
        .getVersions(widget.authUser.uid, widget.noteId);
  }

  Future<void> _restoreVersion(String versionId) async {
    final confirmed = await showNotelyDialog<bool>(
      context: context,
      title: 'Restore version?',
      message: 'This will replace the current note content with this version.',
      actions: [
        NotelyDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        NotelyDialogAction(
          label: 'Restore',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await ref.read(notesServiceProvider).restoreVersion(
            widget.authUser.uid,
            widget.noteId,
            versionId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Version restored')),
      );
      Navigator.of(context).pop(true);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is NoteException ? error.message : "Couldn't restore this version"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final empty = TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2);
    return NotelyPage(
      title: 'Version history',
      body: FutureBuilder<List<NoteVersion>>(
        future: _versionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Couldn't load version history", style: empty));
          }
          final versions = snapshot.data ?? [];
          if (versions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No earlier versions yet. Notely keeps a snapshot at most every 5 minutes while you edit.',
                  textAlign: TextAlign.center,
                  style: empty,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: versions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final version = versions[index];
              final preview = version.decryptionFailed
                  ? "Can't decrypt this version"
                  : (version.content ?? version.title ?? '').trim().replaceAll('\n', ' ');

              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: notely.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: notely.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                formatDateTime(version.createdAt),
                                style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.text),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'v${version.versionNumber}',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  color: notely.text3,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          if (preview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: version.decryptionFailed ? null : () => _restoreVersion(version.id),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
