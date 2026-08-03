
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

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

    if (password.length < 6) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
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

    try {
      await ref.read(authServiceProvider).createUser(
        email: email,
        password: password,
        displayName: firstName,
      );
      if (!mounted) return;
      // Navigate to email verification screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const VerifyEmailView(),
        ),
      );
    } on WeakPasswordAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          leading: GlassIconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            size: 34,
            iconSize: 17,
          ),
          title: Text(
            'Create account',
            style: TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w700, color: notely.text),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                GlassTextField(
                  controller: _firstName,
                  placeholder: 'First Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  keyboardType: TextInputType.name,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                GlassPasswordField(
                  controller: _confirmPassword,
                  placeholder: 'Confirm Password',
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton.custom(
                    onTap: _isLoading ? () {} : _handleRegister,
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
                            'Sign Up',
                            style: TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Log in'),
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
