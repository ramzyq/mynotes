import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({
    super.key,
  });

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  late final TextEditingController _firstName;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _confirmPassword;
  bool _isLoading = false;

  @override
  void initState() {
    _firstName = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
    _confirmPassword = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _handleRegister() async {
    final firstName = _firstName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;
    final messenger = ScaffoldMessenger.of(context);

    if (firstName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    if (password.length < PasswordSecretDeriver.minLength) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least ${PasswordSecretDeriver.minLength} characters')),
      );
      return;
    }

    if (password != confirmPassword) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Firebase gets only the auth secret; the backup key stays in memory
    // until the key setup gate has used it, then is cleared.
    final secrets = await ref
        .read(passwordSecretDeriverProvider)
        .derive(email: email, password: password);
    if (!mounted) return;
    ref.read(pendingPasswordKeyProvider.notifier).state = secrets.backupKey;
    var signedIn = false;
    try {
      await ref.read(authServiceProvider).createUser(
        email: email,
        password: secrets.authSecret,
        displayName: firstName,
      );
      signedIn = true;
      if (!mounted) return;
      // Navigate to email verification screen
      unawaited(Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const VerifyEmailView(),
        ),
      ));
    } on WeakPasswordAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least ${PasswordSecretDeriver.minLength} characters.')),
      );
    } on UserAlreadyExistsAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('That email is already registered.')),
      );
    } on InvalidCredentialAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
    } on GenericAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Registration failed. Please try again.')),
      );
    } finally {
      if (!signedIn && mounted) ref.read(pendingPasswordKeyProvider.notifier).state = null;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return NotelyPage(
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NotelyHeading(
                      title: 'Create your notebook',
                      subtitle: 'Your password also protects your encryption key, so choose one you will remember.',
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _firstName,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: const InputDecoration(labelText: 'First name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    NotelyPasswordField(
                      controller: _password,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 12),
                    NotelyPasswordField(
                      controller: _confirmPassword,
                      label: 'Confirm password',
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _handleRegister(),
                    ),
                    const SizedBox(height: 24),
                    NotelyPrimaryButton(label: 'Create account', loading: _isLoading, onPressed: _handleRegister),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Already have an account?', style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2)),
                        TextButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
