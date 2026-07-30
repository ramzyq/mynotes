import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/auth/presentation/register_view.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart' show GenericAuthException, UserNotFoundAuthException, WrongPasswordAuthException, TooManyRequestsAuthException, GoogleSignInCancelledException;
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/widgets/theme_toggle_button.dart';
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
  bool _showPassword = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        elevation: 0,
        actions: const [ThemeToggleButton()],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Note Log',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Dark notes workspace for ideas and drafts',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 50),
              TextField(
                controller: _email,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                enableSuggestions: false,
                autocorrect: false,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.white, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey[300], thickness: 1),
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
    );
  }
}
