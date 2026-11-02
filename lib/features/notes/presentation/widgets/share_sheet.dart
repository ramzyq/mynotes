import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
import 'package:mynotes/features/collaboration/models/share_link.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

class ShareSheet extends ConsumerStatefulWidget {
  final List<String> collaborators;
  final TextEditingController emailController;
  final Future<String> Function(String email) onAddCollaborator;
  final Future<void> Function(String collaboratorUid) onRemoveCollaborator;
  final Future<ShareLink> Function(String mode) onCreateLink;
  final Future<void> Function(String token) onRevokeLink;

  const ShareSheet({
    super.key,
    required this.collaborators,
    required this.emailController,
    required this.onAddCollaborator,
    required this.onRemoveCollaborator,
    required this.onCreateLink,
    required this.onRevokeLink,
  });

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late List<String> _collaborators;
  bool _isAdding = false;
  String? _error;
  final Map<String, String> _emails = {};
  String _linkMode = 'approval';
  ShareLink? _link;
  bool _isGenerating = false;
  bool _isRevoking = false;

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
      setState(() => _error = _friendlyError(e));
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
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _generateLink() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final link = await widget.onCreateLink(_linkMode);
      if (!mounted) return;
      setState(() => _link = link);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _copyLink() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _shareLink() async {
    final link = _link;
    if (link == null) return;
    await SharePlus.instance.share(ShareParams(text: link.url));
  }

  Future<void> _revokeLink() async {
    final link = _link;
    if (link == null) return;
    setState(() {
      _isRevoking = true;
      _error = null;
    });
    try {
      await widget.onRevokeLink(link.token);
      if (!mounted) return;
      setState(() => _link = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link revoked')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isRevoking = false);
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
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.link, color: notely.text2, size: 18),
              const SizedBox(width: 8),
              Text(
                'Share via link',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Anyone with the link can request access. You approve before they see the note.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: notely.text3,
                ),
          ),
          const SizedBox(height: 12),
          if (_link == null) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'approval',
                  label: Text('Require approval'),
                ),
                ButtonSegment(value: 'open', label: Text('Auto-approve')),
              ],
              selected: {_linkMode},
              onSelectionChanged: (selection) {
                setState(() => _linkMode = selection.first);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generateLink,
                icon: _isGenerating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link_rounded),
                label: const Text('Create share link'),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: notely.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _link!.url,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: notely.text2,
                            fontFamily: 'JetBrains Mono',
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: _shareLink,
                    icon: const Icon(Icons.ios_share, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isRevoking ? null : _revokeLink,
              icon: const Icon(Icons.link_off_rounded, size: 16),
              label: const Text('Revoke link'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is ShareException) return error.message;
  if (error is NoteException) return error.message;
  return 'Something went wrong. Please try again.';
}
