import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/account/providers/account_providers.dart';
import 'package:mynotes/features/account/services/account_deletion_service.dart';
import 'package:mynotes/features/auth/presentation/password_forms.dart';

/// Deletes the account and all its data, after the user confirms who they
/// are and that they mean it.
class DeleteAccountView extends ConsumerStatefulWidget {
  const DeleteAccountView({super.key, required this.authUser});
  final AuthUser authUser;

  @override
  ConsumerState<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends ConsumerState<DeleteAccountView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _confirmWord = 'DELETE';

  bool get _confirmed => _confirm.text.trim().toUpperCase() == _confirmWord;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  static bool _offline(Object cause) =>
      cause is NetworkAuthException ||
      (cause is FirebaseException && (cause.code == 'unavailable' || cause.code == 'deadline-exceeded'));

  /// Says how far deletion got, so nobody is told notes are gone when they
  /// aren't (or the reverse).
  String _message(Object error) {
    if (error is! AccountDeletionException) return 'Something went wrong. Nothing was deleted.';
    final cause = error.cause;
    switch (error.stage) {
      case AccountDeletionStage.verifying:
        if (cause is WrongPasswordAuthException) return "That password isn't right. Nothing was deleted.";
        if (cause is GoogleSignInCancelledException) return 'Confirm with Google to delete your account.';
        if (cause is TooManyRequestsAuthException) return 'Too many attempts. Try again later. Nothing was deleted.';
        if (_offline(cause)) return "You're offline. Deleting your account needs a connection. Nothing was deleted.";
        return "Couldn't confirm it's you. Nothing was deleted.";
      case AccountDeletionStage.deletingData:
        return _offline(cause)
            ? 'The connection dropped while deleting, so some notes may already be gone. '
                  'Reconnect and try again to delete the rest.'
            : 'Deleting stopped before it finished, so some notes may already be gone. '
                  'Try again to delete the rest.';
      case AccountDeletionStage.deletingAccount:
        return 'Your notes are deleted, but the account itself couldn\'t be removed yet. '
            'Stay signed in and try again.';
    }
  }

  Future<void> _delete() async {
    if (widget.authUser.hasPassword && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(accountDeletionServiceProvider)
          .deleteAccount(user: widget.authUser, password: widget.authUser.hasPassword ? _password.text : null);
      // Signed out now: the app shows the sign-in screen underneath.
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Your account and notes were deleted.')));
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    // While deleting, leaving would hide whether it finished.
    return PopScope(
      canPop: !_busy,
      child: NotelyPage(
        title: 'Delete account',
        body: PasswordFormBody(
          children: [
            const NotelyHeading(
              title: 'Delete your account?',
              subtitle:
                  'This permanently deletes your notes, their history, comments you posted, share links, '
                  'and your encrypted key backup. It cannot be undone, by you or by us.',
            ),
            const SizedBox(height: 16),
            const PasswordFormNote(
              'Notes other people shared with you stay with their owners. Copies that people you shared with '
              'already opened on their devices can\'t be removed. To keep a copy, export a backup first.',
            ),
            const SizedBox(height: 24),
            if (widget.authUser.hasPassword) ...[
              NotelyPasswordField(controller: _password, label: 'Your password', enabled: !_busy),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _confirm,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Type $_confirmWord to confirm'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.danger),
              ),
            ],
            const SizedBox(height: 16),
            NotelyPrimaryButton(
              label: widget.authUser.hasPassword ? 'Delete my account' : 'Confirm with Google and delete',
              danger: true,
              loading: _busy,
              onPressed: _confirmed ? _delete : null,
            ),
          ],
        ),
      ),
    );
  }
}
