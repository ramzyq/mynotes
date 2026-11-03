import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

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
        const SnackBar(content: Text('Verification email sent. Check your inbox.')),
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
          const SnackBar(content: Text('Not verified yet. Open the link in the email first.')),
        );
      }
    } catch (_) {
      // Silently ignore reload errors for auto-check
    } finally {
      if (mounted && !silent) setState(() => _isChecking = false);
    }
  }

  Future<void> _showVerifiedDialogAndNavigate() async {
    await showNotelyDialog<void>(
      context: context,
      barrierDismissible: false,
      title: 'Email verified',
      message: 'Your account is ready. Next, Notely sets up the key that encrypts your notes.',
      actions: [
        NotelyDialogAction(label: 'Continue', isPrimary: true, onPressed: () => Navigator.of(context).pop()),
      ],
    );
    if (!mounted) return;
    unawaited(Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const _VerifiedRedirect(),
      ),
      (route) => false,
    ));
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
    final notely = NotelyTheme.of(context);

    return NotelyPage(
      showBack: false,
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: notely.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: notely.border),
                      ),
                      child: Icon(Icons.mark_email_unread_outlined, size: 22, color: notely.violet),
                    ),
                  ),
                  const SizedBox(height: 24),
                  NotelyHeading(
                    title: 'Check your inbox',
                    subtitle: 'We sent a link to $email. Open it on any device; this screen continues on its own once you have.',
                  ),
                  const SizedBox(height: 32),
                  NotelyPrimaryButton(
                    label: "I've verified my email",
                    loading: _isChecking,
                    onPressed: () => _checkEmailVerified(),
                  ),
                  const SizedBox(height: 12),
                  NotelySecondaryButton(
                    label: _isSending ? 'Sending…' : 'Send the link again',
                    onPressed: _isSending ? null : _sendVerificationEmail,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _signOut,
                    style: TextButton.styleFrom(foregroundColor: notely.text2),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// A simple widget that rebuilds from the AuthenticationWrapper,
/// ensuring the verified user lands on the HomeView.
class _VerifiedRedirect extends StatelessWidget {
  const _VerifiedRedirect();

  @override
  Widget build(BuildContext context) {
    return const AuthenticationWrapper();
  }
}
