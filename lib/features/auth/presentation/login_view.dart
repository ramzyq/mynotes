import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
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

  Future<void> _handleLogin() async {
    final email = _email.text.trim();
    final password = _password.text;
    final messenger = ScaffoldMessenger.of(context);

    if (email.isEmpty || password.isEmpty) {
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

    if (password.length < 6) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await ref.read(authServiceProvider).logIn(
        email: email,
        password: password,
      );
      if (!mounted) return;
      await _ensureMasterKey(password);
      if (!mounted) return;
      // If email is not verified, navigate to verification screen
      if (!user.isEmailVerified) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const VerifyEmailView(),
          ),
        );
      }
    } on UserNotFoundAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('User not found. Please sign up.')),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Derive and persist the Master Key from the password on first login.
  /// Failures are ignored: KeyManager lazily ensures a key on first use.
  Future<void> _ensureMasterKey(String password) async {
    try {
      final keyManager = ref.read(keyManagerProvider);
      if (!await keyManager.hasMasterKey()) {
        await keyManager.initializeMasterKey(password);
      }
    } catch (_) {
      // Non-critical: KeyManager.ensureMasterKey() covers this path.
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
          title: Text(
            'Login',
            style: TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w700, color: notely.text),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: const NotelyWordmark(size: 28),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Your private notes workspace',
                    style: TextStyle(fontSize: 16, color: notely.text3),
                  ),
                ),
                const SizedBox(height: 50),
                GlassTextField(
                  controller: _email,
                  placeholder: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                GlassPasswordField(
                  controller: _password,
                  placeholder: 'Password',
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton.custom(
                    onTap: _isLoading ? () {} : _handleLogin,
                    enabled: !_isLoading,
                    height: 54,
                    glowColor: notely.violet,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: notely.border, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          color: notely.text3,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: notely.border, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: SignInButton(
                    Buttons.google,
                    text: 'Continue with Google',
                    onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RegisterView(),
                                ),
                              );
                            },
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
