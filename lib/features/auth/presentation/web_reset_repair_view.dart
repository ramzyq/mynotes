import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/presentation/password_forms.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

/// For an account whose password was set on Firebase's hosted reset page.
/// Firebase knows that password, so it is used once to sign in and is then
/// replaced by a new one chosen here.
class WebResetRepairView extends ConsumerStatefulWidget {
  const WebResetRepairView({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  ConsumerState<WebResetRepairView> createState() => _WebResetRepairViewState();
}

class _WebResetRepairViewState extends ConsumerState<WebResetRepairView> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _webPassword = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _webPassword.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _show(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _repair() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _webPassword.text.isEmpty) {
      return _show('Enter your email and the password you set on the web page.');
    }
    final problem = newPasswordProblem(_password.text, _confirm.text);
    if (problem != null) return _show(problem);
    if (_password.text == _webPassword.text) {
      return _show('Choose a different password from the one you set on the web page.');
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(passwordAccountServiceProvider).repairWebReset(
            email: email,
            webPassword: _webPassword.text,
            newPassword: _password.text,
            holdPasswordKey: (key) => ref.read(pendingPasswordKeyProvider.notifier).state = key,
          );
      // Signed in: the app's home is now the notes, under these screens.
      navigator.popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _show(passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotelyPage(
      title: 'Finish your reset',
      body: PasswordFormBody(children: [
        const NotelyHeading(
          title: 'Set on the web page?',
          subtitle: "A password set on the web page can't keep your notes encrypted, "
              "because it was sent as typed. Sign in with it once and choose a new "
              'one here.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        NotelyPasswordField(
          controller: _webPassword,
          label: 'Password you set on the web page',
          enabled: !_busy,
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
          onSubmitted: (_) => _repair(),
        ),
        const SizedBox(height: 16),
        NotelyPrimaryButton(label: 'Sign in and replace it', loading: _busy, onPressed: _repair),
      ]),
    );
  }
}
