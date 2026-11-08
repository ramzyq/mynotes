import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/account/providers/account_providers.dart';
import 'package:mynotes/features/account/services/account_deletion_service.dart';
import 'package:mynotes/features/auth/presentation/desk/auth_desk.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_layout.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_note.dart';

/// Deletes the account and all its data, after the user confirms who they
/// are and that they mean it.
///
/// Laid out so it's plain what goes: a list of everything deleted, what
/// stays, then the password (or Google/Apple) and DELETE typed into red
/// letter boxes. While it runs, the notes fall away and the real stages tick
/// past; when it's done, a quiet goodbye.
class DeleteAccountView extends ConsumerStatefulWidget {
  const DeleteAccountView({super.key, required this.authUser});
  final AuthUser authUser;

  @override
  ConsumerState<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends ConsumerState<DeleteAccountView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  bool _busy = false;
  bool _done = false;
  String? _error;

  /// The stage running now, while deleting.
  AccountDeletionStage? _stage;

  static const _confirmWord = 'DELETE';

  bool get _confirmed => _confirm.text.trim().toUpperCase() == _confirmWord;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  static bool _offline(Object cause) =>
      cause is NetworkAuthException ||
      (cause is FirebaseException && (cause.code == 'unavailable' || cause.code == 'deadline-exceeded'));

  /// Says how far deletion got, so nobody is told notes are gone when they
  /// aren't (or the reverse).
  String _message(Object error) {
    if (error is! AccountDeletionException) return 'Something went wrong. Nothing was deleted.';
    final cause = error.cause;
    switch (error.stage) {
      case AccountDeletionStage.verifying:
        if (cause is WrongPasswordAuthException) return "That password isn't right. Nothing was deleted.";
        if (cause is GoogleSignInCancelledException) return 'Confirm with Google to delete your account.';
        if (cause is AppleSignInCancelledException) return 'Confirm with Apple to delete your account.';
        if (cause is TooManyRequestsAuthException) return 'Too many attempts. Try again later. Nothing was deleted.';
        if (_offline(cause)) return "You're offline. Deleting your account needs a connection. Nothing was deleted.";
        return "Couldn't confirm it's you. Nothing was deleted.";
      case AccountDeletionStage.deletingData:
        return _offline(cause)
            ? 'The connection dropped while deleting, so some notes may already be gone. '
                  'Reconnect and try again to delete the rest.'
            : 'Deleting stopped before it finished, so some notes may already be gone. '
                  'Try again to delete the rest.';
      case AccountDeletionStage.deletingAccount:
        return 'Your notes are deleted, but the account itself couldn\'t be removed yet. '
            'Stay signed in and try again.';
    }
  }

  void _typed(String value) {
    // A selection tick per letter, so it feels like stamping each one.
    NotelyHaptics.select();
    setState(() {});
  }

  Future<void> _delete() async {
    if (widget.authUser.hasPassword && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    FocusScope.of(context).unfocus();
    NotelyHaptics.error(); // One firm knock: this is the serious button.
    setState(() {
      _busy = true;
      _error = null;
      _stage = AccountDeletionStage.verifying;
    });
    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount(
            user: widget.authUser,
            password: widget.authUser.hasPassword ? _password.text : null,
            onStage: (stage) {
              if (mounted) setState(() => _stage = stage);
            },
          );
      // Signed out now: the app shows the sign-in screen underneath.
      if (mounted) setState(() => _done = true);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        NotelyHaptics.error();
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = null;
        });
      }
    }
  }

  String get _buttonLabel {
    if (widget.authUser.hasPassword) return 'Delete my account';
    return widget.authUser.usesApple ? 'Confirm with Apple and delete' : 'Confirm with Google and delete';
  }

  @override
  Widget build(BuildContext context) {
    // While deleting, leaving would hide whether it finished.
    return PopScope(
      canPop: !_busy,
      child: _done
          ? _Gone(onDone: () => Navigator.of(context).popUntil((route) => route.isFirst))
          : NotelyPage(
              title: 'Delete account',
              body: SafeArea(
                top: false,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FallingNotes(falling: _busy),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: NotelyMotion.of(context, NotelyMotion.medium),
                            child: _busy ? _progress(context) : _form(context),
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

  Widget _form(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RedTitle(plain: 'Delete your', accent: 'account?'),
        const SizedBox(height: 8),
        Text(
          "This can't be undone, by you or by us. Here's what goes:",
          style: TextStyle(fontFamily: 'Geist', fontSize: 14, height: 1.45, color: notely.text2),
        ),
        const SizedBox(height: 12),
        const _GoesList(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: notely.surface2, borderRadius: BorderRadius.circular(12)),
          child: Text(
            "Notes other people shared with you stay with their owners. Copies that people you shared with "
            "already opened on their devices can't be removed. To keep a copy, export a backup first.",
            style: TextStyle(fontFamily: 'Geist', fontSize: 12.5, height: 1.5, color: notely.text2),
          ),
        ),
        const SizedBox(height: 18),
        if (widget.authUser.hasPassword) ...[
          NotelyPasswordField(controller: _password, label: 'Your password', enabled: !_busy),
          const SizedBox(height: 14),
        ],
        Text.rich(
          TextSpan(text: 'Type ', children: [
            TextSpan(text: _confirmWord, style: TextStyle(color: notely.danger, fontWeight: FontWeight.w600)),
            const TextSpan(text: ' to confirm'),
          ]),
          style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text2),
        ),
        const SizedBox(height: 8),
        _LetterBoxes(
          controller: _confirm,
          focusNode: _confirmFocus,
          word: _confirmWord,
          enabled: !_busy,
          onChanged: _typed,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.danger)),
        ],
        const SizedBox(height: 16),
        NotelyPrimaryButton(
          label: _buttonLabel,
          danger: true,
          loading: _busy,
          onPressed: _confirmed ? _delete : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(foregroundColor: notely.text2),
          child: const Text('Keep my account'),
        ),
      ],
    );
  }

  Widget _progress(BuildContext context) {
    final notely = NotelyTheme.of(context);
    const steps = [
      (AccountDeletionStage.verifying, "Confirming it's you"),
      (AccountDeletionStage.deletingData, 'Deleting your notes and data'),
      (AccountDeletionStage.deletingAccount, 'Deleting your account'),
    ];
    final now = _stage?.index ?? 0;
    return Column(
      key: const ValueKey('progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RedTitle(plain: 'Deleting', accent: '…'),
        const SizedBox(height: 8),
        Text(
          "Keep Notely open until this finishes. If it's interrupted, trying again picks up where it stopped.",
          style: TextStyle(fontFamily: 'Geist', fontSize: 14, height: 1.45, color: notely.text2),
        ),
        const SizedBox(height: 18),
        for (final (stage, label) in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(
                width: 20,
                height: 20,
                child: stage.index < now
                    ? Icon(Icons.check_circle, size: 20, color: notely.success)
                    : stage.index == now
                        ? CircularProgressIndicator(strokeWidth: 2.2, color: notely.danger)
                        : Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: notely.border, width: 2)),
                          ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14.5,
                  color: stage.index == now ? notely.text : (stage.index < now ? notely.text2 : notely.text3),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

/// "Delete your *account?*", the accent in red.
class _RedTitle extends StatelessWidget {
  const _RedTitle({required this.plain, required this.accent});
  final String plain;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Text.rich(
      TextSpan(text: '$plain ', children: [
        TextSpan(text: accent, style: TextStyle(fontStyle: FontStyle.italic, color: notely.danger)),
      ]),
      style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 34, height: 1.05, color: notely.text),
    );
  }
}

/// Everything that's deleted, one line each.
class _GoesList extends StatelessWidget {
  const _GoesList();

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    const items = [
      'Your notes',
      'Their history and versions',
      'Comments you posted',
      'Share links',
      'Your encrypted key backup',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: notely.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notely.border),
      ),
      child: Column(children: [
        for (var i = 0; i < items.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: notely.border)),
            ),
            child: Row(children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: notely.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, size: 13, color: notely.danger),
              ),
              const SizedBox(width: 10),
              Text(items[i], style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.text)),
            ]),
          ),
      ]),
    );
  }
}

/// A box per letter of [word]: each fills in red as it's typed correctly.
/// A real text field sits on top, invisible, so the keyboard, paste and
/// screen readers work as normal.
class _LetterBoxes extends StatelessWidget {
  const _LetterBoxes({
    required this.controller,
    required this.focusNode,
    required this.word,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String word;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final typed = controller.text.toUpperCase();
    return SizedBox(
      height: 50,
      child: Stack(
        children: [
          Row(children: [
            for (var i = 0; i < word.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Builder(builder: (context) {
                  final ch = i < typed.length ? typed[i] : '';
                  final right = ch == word[i];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: right ? notely.danger.withValues(alpha: 0.10) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: right ? notely.danger : (ch.isEmpty ? notely.borderStrong : notely.text3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      ch,
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 19, color: right ? notely.danger : notely.text2),
                    ),
                  );
                }),
              ),
            ],
          ]),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                maxLength: word.length,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                onChanged: onChanged,
                decoration: const InputDecoration(labelText: 'Type DELETE to confirm', counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three notes from the logo, falling away while the account is
/// deleted.
class _FallingNotes extends StatelessWidget {
  const _FallingNotes({required this.falling});
  final bool falling;

  @override
  Widget build(BuildContext context) {
    final duration = NotelyMotion.of(context, const Duration(milliseconds: 900));
    Widget note(DeskNoteRole role, double dx, double turn, double fallTurn, int delayMs) {
      return TweenAnimationBuilder<double>(
        tween: Tween(end: falling ? 1 : 0),
        duration: duration + Duration(milliseconds: delayMs),
        curve: Interval(delayMs / (900 + delayMs), 1, curve: Curves.easeInCubic),
        builder: (context, t, child) => Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, 70 * t),
            child: Transform.rotate(angle: (turn + fallTurn * t) * math.pi / 180, child: Transform.scale(scale: 1 - 0.4 * t, child: child)),
          ),
        ),
        child: SizedBox(
          width: 104,
          height: 90,
          child: DeskNoteFace(
            role: role,
            content: const DeskNoteWriting(lines: [1, 0.6]),
            shadow: false,
          ),
        ),
      );
    }

    return SizedBox(
      height: 128,
      child: Stack(alignment: Alignment.center, children: [
        note(DeskNoteRole.left, -64, -12, -20, 0),
        note(DeskNoteRole.right, 64, 10, 22, 250),
        note(DeskNoteRole.middle, 0, -2, 0, 500),
      ]),
    );
  }
}

/// After deletion: a quiet goodbye, then the sign-in screen.
class _Gone extends StatelessWidget {
  const _Gone({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Scaffold(
      backgroundColor: notely.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DeskTitle("It's", 'gone.'),
                const SizedBox(height: 12),
                Text(
                  'Your account and notes were deleted. Thanks for writing with Notely.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Geist', fontSize: 15, height: 1.5, color: notely.text2),
                ),
                const SizedBox(height: 24),
                SizedBox(width: 220, child: NotelySecondaryButton(label: 'Back to sign in', onPressed: onDone)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
