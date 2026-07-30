import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/settings/presentation/widgets/theme_toggle_button.dart';

class VerifyEmailView extends ConsumerStatefulWidget {
  const VerifyEmailView({
    super.key,
  });

  @override
  ConsumerState<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends ConsumerState<VerifyEmailView> {
  bool _isSending = false;
  bool _isChecking = false;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
    // Periodically check if the user has verified their email
    _autoCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkEmailVerified(silent: true),
    );
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || user.isEmailVerified) return;

    setState(() => _isSending = true);
    try {
      await authService.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent! Check your inbox.')),
      );
    } on GenericAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('too-many-requests')
                ? 'Too many requests. Please wait before trying again.'
                : 'Failed to send verification email. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkEmailVerified({bool silent = false}) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    if (!silent) setState(() => _isChecking = true);

    try {
      await authService.reloadCurrentUser();
      final updatedUser = authService.currentUser;
      if (updatedUser != null && updatedUser.isEmailVerified) {
        _autoCheckTimer?.cancel();
        if (!mounted) return;
        await _showVerifiedDialogAndNavigate();
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not yet verified. Please check your inbox.')),
        );
      }
    } catch (_) {
      // Silently ignore reload errors for auto-check
    } finally {
      if (mounted && !silent) setState(() => _isChecking = false);
    }
  }

  Future<void> _showVerifiedDialogAndNavigate() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified, color: Colors.green, size: 48),
        title: const Text('Email Verified!'),
        content: const Text(
          'Your email has been successfully verified. Welcome to Note Log!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const _VerifiedRedirect(),
      ),
      (route) => false,
    );
  }

  Future<void> _signOut() async {
    _autoCheckTimer?.cancel();
    await ref.read(authServiceProvider).logOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authServiceProvider).currentUser?.email ?? 'your email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        automaticallyImplyLeading: false,
        actions: const [ThemeToggleButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'Verify your email',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ve sent a verification email to\n$email',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Click the link in the email to verify your account, then tap the button below.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isChecking ? null : () => _checkEmailVerified(),
              icon: _isChecking
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('I\'ve verified my email'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSending ? null : _sendVerificationEmail,
              icon: _isSending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.email_outlined),
              label: const Text('Resend verification email'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _signOut,
              child: const Text('Sign out and go back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple widget that rebuilds from the AuthenticationWrapper,
/// ensuring the verified user lands on the HomeView.
class _VerifiedRedirect extends StatelessWidget {
  const _VerifiedRedirect();

  @override
  Widget build(BuildContext context) {
    return const AuthenticationWrapper();
  }
}
