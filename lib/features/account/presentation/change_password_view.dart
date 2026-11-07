import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/presentation/password_forms.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';

class ChangePasswordView extends ConsumerStatefulWidget {
  const ChangePasswordView({super.key, required this.authUser});
  final AuthUser authUser;

  @override
  ConsumerState<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final messenger = ScaffoldMessenger.of(context);
    void show(String message) => messenger.showSnackBar(SnackBar(content: Text(message)));
    if (_current.text.isEmpty) return show('Enter your current password.');
    final problem = newPasswordProblem(_password.text, _confirm.text);
    if (problem != null) return show(problem);

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(passwordAccountServiceProvider).changePassword(
            user: widget.authUser,
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      navigator.pop();
      show('Password changed.');
    } on PasswordBackupNotUpdatedException catch (error) {
      // The password itself did change; leave the screen and say what's left.
      navigator.pop();
      show(passwordErrorMessage(error));
    } catch (error) {
      if (mounted) show(passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotelyPage(
      title: 'Change password',
      body: PasswordFormBody(children: [
        const PasswordFormNote(
          'Your password also unlocks your encrypted key backup on new devices. '
          "It never leaves this device: we can't see it or recover it.",
        ),
        const SizedBox(height: 24),
        NotelyPasswordField(controller: _current, label: 'Current password', enabled: !_busy),
        const SizedBox(height: 12),
        NotelyPasswordField(
          controller: _password,
          label: 'New password',
          enabled: !_busy,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 12),
        NotelyPasswordField(
          controller: _confirm,
          label: 'Confirm new password',
          enabled: !_busy,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _change(),
        ),
        const SizedBox(height: 16),
        NotelyPrimaryButton(label: 'Change password', loading: _busy, onPressed: _change),
      ]),
    );
  }
}
