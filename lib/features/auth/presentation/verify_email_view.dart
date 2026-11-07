import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
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
    // No email here: registration sent one, and this screen also shows on
    // every launch until the email is verified. Resending is a button.
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
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSending = true);
    try {
      await authService.sendEmailVerification();
      messenger.showSnackBar(
        const SnackBar(content: Text('Verification email sent. Check your inbox.')),
      );
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      messenger.showSnackBar(SnackBar(
        content: Text(
          '$error'.contains('too-many-requests')
              ? 'Too many requests. Wait a few minutes before sending another.'
              : "Couldn't send the email. Check your connection and try again.",
        ),
      ));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Reload the account. Once the email is verified, the reload makes
  /// AuthenticationWrapper move on by itself (it follows userChanges).
  Future<void> _checkEmailVerified({bool silent = false}) async {
    final authService = ref.read(authServiceProvider);
    if (authService.currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);

    if (!silent) setState(() => _isChecking = true);
    try {
      await authService.reloadCurrentUser();
      final verified = authService.currentUser?.isEmailVerified ?? false;
      if (verified) {
        _autoCheckTimer?.cancel();
        // Supersedes anything still showing, like "Verification email sent".
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Email verified.')));
      } else if (!silent) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Not verified yet. Open the link in the email first.')),
        );
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (!silent) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't check. Check your connection and try again.")),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _isChecking = false);
    }
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
