import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore version?'),
        content: const Text(
          'This will replace the current note content with this version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Version history'),
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
            return const Center(
              child: Text(
                'No versions yet',
                style: TextStyle(color: Colors.white54),
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
                        backgroundColor:
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          '$versionNumber',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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
                                  ?.copyWith(color: Colors.white54),
                            ),
                            if (previewText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                previewText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
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
    );
  }
}
