import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/presentation/desk/auth_desk.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_scenes.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/auth/services/resend_cooldown.dart';

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
  final _envelope = GlobalKey<EnvelopeSceneState>();

  /// Seconds until "Send the link again" is offered.
  final _cooldown = CooldownTicker();

  @override
  void initState() {
    super.initState();
    // No email here: registration sent one, and this screen also shows on
    // every launch until the email is verified. Resending is a button.
    _autoCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkEmailVerified(silent: true),
    );
    _loadCooldown();
  }

  /// Picks up the wait where it was, even across restarts.
  Future<void> _loadCooldown() async {
    final email = ref.read(authServiceProvider).currentUser?.email;
    if (email == null) return;
    final left = await ref.read(resendCooldownProvider).remaining(ResendPurpose.verify, email);
    if (mounted) _cooldown.run(left);
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _cooldown.dispose();
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
      NotelyHaptics.light();
      _envelope.currentState?.play();
      // Saved in the background: the wait starts on screen straight away.
      unawaited(ref.read(resendCooldownProvider).start(ResendPurpose.verify, user.email));
      if (mounted) _cooldown.run(ResendCooldown.length);
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
        NotelyHaptics.success();
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

    return AuthDesk(
      scene: EnvelopeScene(key: _envelope),
      showMiddle: false,
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DeskTitle('Check your', 'inbox.'),
          DeskSubtitle('We sent a link to $email. Open it on any device; this screen continues on its own once you have.'),
          NotelyPrimaryButton(
            label: "I've verified my email",
            loading: _isChecking,
            onPressed: () => _checkEmailVerified(),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<int>(
            valueListenable: _cooldown,
            builder: (context, seconds, _) => NotelySecondaryButton(
              label: _isSending
                  ? 'Sending…'
                  : seconds > 0
                      ? 'Send again in ${CooldownTicker.format(seconds)}'
                      : 'Send the link again',
              onPressed: _isSending || seconds > 0 ? null : _sendVerificationEmail,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _signOut,
            style: TextButton.styleFrom(foregroundColor: notely.text2),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
