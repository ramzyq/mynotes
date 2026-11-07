import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/features/auth/presentation/forgot_password_view.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/presentation/register_view.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart' show GenericAuthException, UserNotFoundAuthException, WrongPasswordAuthException, TooManyRequestsAuthException, GoogleSignInCancelledException;
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_wordmark.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:sign_in_button/sign_in_button.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({
    super.key,
  });

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _isLoading = false;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _handleGoogleSignIn() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Success - AuthenticationWrapper will handle navigation
    } on GoogleSignInCancelledException {
      // User cancelled the sign-in flow, nothing to show
    } on GenericAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Google sign-in failed. Please try again.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final email = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => ForgotPasswordView(initialEmail: _email.text.trim()),
    ));
    if (email == null || !mounted) return;
    _email.text = email;
    _password.clear();
    messenger.showSnackBar(
      const SnackBar(content: Text('Password changed. Sign in with your new password.')),
    );
  }

  Future<void> _handleLogin() async {
    final email = _email.text.trim();
    final password = _password.text;
    final messenger = ScaffoldMessenger.of(context);

    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your email and password')),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }

    if (password.length < PasswordSecretDeriver.minLength) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least ${PasswordSecretDeriver.minLength} characters')),
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
      final user = await ref.read(authServiceProvider).logIn(
        email: email,
        password: secrets.authSecret,
      );
      signedIn = true;
      if (!mounted) return;
      // If email is not verified, navigate to verification screen
      if (!user.isEmailVerified) {
        unawaited(Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const VerifyEmailView(),
          ),
        ));
      }
    } on UserNotFoundAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('No account with that email. Create one below.')),
      );
    } on WrongPasswordAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Invalid email or password.')),
      );
    } on TooManyRequestsAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Too many attempts. Try again later.')),
      );
    } on GenericAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Login failed. Please try again.')),
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
    return Scaffold(
      backgroundColor: notely.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: NotelyWordmark(size: 18)),
                    const SizedBox(height: 48),
                    const NotelyHeading(
                      title: 'Sign in',
                      subtitle: 'Your notes are encrypted on your device. Only you can read them.',
                    ),
                    const SizedBox(height: 32),
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    NotelyPrimaryButton(label: 'Sign in', loading: _isLoading, onPressed: _handleLogin),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: SignInButton(
                        Buttons.google,
                        text: 'Continue with Google',
                        elevation: 0,
                        onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: notely.borderStrong),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('New to Notely?', style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2)),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const RegisterView()),
                                  ),
                          child: const Text('Create an account'),
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
