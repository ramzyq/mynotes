import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
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
  late Future<List<Map<String, dynamic>>> _versionsFuture;

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
    final confirmed = await GlassDialog.show<bool>(
      context: context,
      title: 'Restore version?',
      message: 'This will replace the current note content with this version.',
      actions: [
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlassDialogAction(
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to restore version')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return GlassPage(
      background: const NotelyBackground(),
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: GlassAppBar(
          centerTitle: false,
          leading: GlassIconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            size: 34,
            iconSize: 17,
          ),
          title: Text(
            'Version history',
            style: TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w700, color: notely.text),
          ),
        ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _versionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          final versions = snapshot.data ?? [];
          if (versions.isEmpty) {
            return Center(
              child: Text(
                'No versions yet',
                style: TextStyle(color: notely.text3),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final version = versions[index];
              final createdAt = (version['createdAt'] as Timestamp).toDate();
              final versionNumber = version['versionNumber'] as int;
              final encrypted = version.containsKey('encryptedContent');
              final preview = encrypted
                  ? 'Encrypted version'
                  : ((version['content'] as String?) ?? '').trim();
              final previewText = preview.length > 100
                  ? '${preview.substring(0, 100)}...'
                  : preview;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: notely.violet.withValues(alpha: 0.2),
                        child: Text(
                          '$versionNumber',
                          style: TextStyle(
                            color: notely.violet,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${createdAt.month}/${createdAt.day}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: notely.text3),
                            ),
                            if (previewText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                previewText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: notely.text2),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () =>
                            _restoreVersion(version['id'] as String),
                        child: const Text('Restore'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}
