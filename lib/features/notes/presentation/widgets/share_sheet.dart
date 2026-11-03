import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
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
    final caption = TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2);
    final section = TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.text);
    return NotelySheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Share note', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'People you add get their own key to this note. They can read and comment; only you can edit.',
            style: caption,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.emailController,
                  enabled: !_isAdding,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _isAdding ? null : _submit(),
                  decoration: const InputDecoration(hintText: 'Email address'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isAdding ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: _isAdding
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.danger)),
            ),
          const SizedBox(height: 16),
          Text('People with access', style: section),
          const SizedBox(height: 8),
          if (_collaborators.isEmpty)
            Text('Only you', style: caption)
          else
            for (final uid in _collaborators)
              Container(
                height: 48,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: notely.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: notely.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: notely.text3, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _emails[uid] ?? uid,
                        style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _isAdding ? null : () => _remove(uid),
                      style: TextButton.styleFrom(foregroundColor: notely.text2),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text('Share with a link', style: section),
          const SizedBox(height: 4),
          Text(
            _linkMode == 'approval'
                ? 'Anyone with the link can ask for access. You approve each request.'
                : 'Anyone with the link who signs in gets access right away.',
            style: caption,
          ),
          const SizedBox(height: 12),
          if (_link == null) ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: notely.violetSoft2,
                selectedForegroundColor: notely.violetInk,
                foregroundColor: notely.text2,
                side: BorderSide(color: notely.borderStrong),
                textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500),
              ),
              segments: const [
                ButtonSegment(value: 'approval', label: Text('Ask me first')),
                ButtonSegment(value: 'open', label: Text('Anyone with link')),
              ],
              selected: {_linkMode},
              onSelectionChanged: (selection) => setState(() => _linkMode = selection.first),
            ),
            const SizedBox(height: 12),
            NotelySecondaryButton(
              label: _isGenerating ? 'Creating link…' : 'Create link',
              leading: Icon(Icons.add_link, size: 18, color: notely.text2),
              onPressed: _isGenerating ? null : _generateLink,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: notely.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: notely.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _link!.url,
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: notely.text2),
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
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _isRevoking ? null : _revokeLink,
                style: TextButton.styleFrom(foregroundColor: notely.danger),
                child: const Text('Turn off link'),
              ),
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
