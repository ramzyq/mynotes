import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/presentation/password_forms.dart';
import 'package:mynotes/features/auth/presentation/web_reset_repair_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

/// Reset a forgotten password without Firebase's web page: the email's link
/// is pasted here, and the app sets the new password (as an auth secret).
/// Pops with the account email once the password is set.
class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _link = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _link.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _show(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return _show('Enter the email you signed up with.');
    setState(() => _busy = true);
    try {
      await ref.read(passwordAccountServiceProvider).sendResetEmail(email);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) _show(passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPassword() async {
    final problem = newPasswordProblem(_password.text, _confirm.text);
    if (problem != null) return _show(problem);
    setState(() => _busy = true);
    try {
      final email = await ref
          .read(passwordAccountServiceProvider)
          .completeReset(linkOrCode: _link.text, newPassword: _password.text);
      if (mounted) Navigator.of(context).pop(email);
    } catch (error) {
      if (mounted) _show(passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotelyPage(
      title: 'Reset password',
      body: PasswordFormBody(children: [
        const NotelyHeading(
          title: 'Forgot your password?',
          subtitle: "We'll email you a reset link. You finish the reset here, in the app.",
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 16),
        _sent
            ? NotelySecondaryButton(label: 'Send again', onPressed: _busy ? null : _send)
            : NotelyPrimaryButton(label: 'Send reset link', loading: _busy, onPressed: _send),
        if (_sent) ...[
          const SizedBox(height: 32),
          const PasswordFormNote(
            'If an account uses that email, a reset link is on its way. '
            'Copy the link from the email and paste it below. '
            "Don't set a password on the web page the link opens: your notes "
            'stay encrypted only when the new password is chosen in the app.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _link,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Reset link from the email'),
          ),
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
            onSubmitted: (_) => _setPassword(),
          ),
          const SizedBox(height: 16),
          NotelyPrimaryButton(label: 'Set new password', loading: _busy, onPressed: _setPassword),
        ],
        const SizedBox(height: 24),
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WebResetRepairView(initialEmail: _email.text.trim()),
                  )),
          child: const Text('Already set a new password on the web page?'),
        ),
      ]),
    );
  }
}
