import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/encryption/presentation/recovery_code_widgets.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/core/theme/notely_motion.dart';
import 'package:mynotes/features/auth/presentation/desk/auth_desk.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

/// Ensures the user's master key is available on this device before [child]
/// (which decrypts notes) is shown. Handles first-time setup, restoring from
/// the encrypted backup, and recovery-code entry.
class KeySetupGate extends ConsumerStatefulWidget {
  const KeySetupGate({super.key, required this.authUser, required this.child});

  final AuthUser authUser;
  final Widget child;

  @override
  ConsumerState<KeySetupGate> createState() => _KeySetupGateState();
}

enum _Phase { loading, showCode, enterCode, ready, error }

class _KeySetupGateState extends ConsumerState<KeySetupGate> {
  _Phase _phase = _Phase.loading;
  String? _recoveryCode;
  bool _codeSaved = false;
  bool _busy = false;
  String? _codeError;

  /// The code typed (or pasted) into the group boxes.
  String _enteredCode = '';
  final _boxes = GlobalKey<RecoveryCodeBoxesState>();

  /// The right code went in: the padlock springs open before the notes.
  bool _opened = false;

  /// "Copied" shows on the button for a moment.
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() => _phase = _Phase.loading);
    try {
      final passwordKey = ref.read(pendingPasswordKeyProvider);
      final result = await ref
          .read(keyBackupServiceProvider)
          .prepare(uid: widget.authUser.uid, passwordKey: passwordKey);
      if (!mounted) return;
      switch (result) {
        case KeySetupReady():
          _clearPassword();
          setState(() => _phase = _Phase.ready);
        case KeySetupShowRecoveryCode(:final code):
          _clearPassword();
          setState(() {
            _recoveryCode = code;
            _phase = _Phase.showCode;
          });
        case KeySetupNeedsRecoveryCode():
          // Keep the password key: recovery re-wraps the password slot with it.
          setState(() => _phase = _Phase.enterCode);
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  void _clearPassword() {
    ref.read(pendingPasswordKeyProvider.notifier).state = null;
  }

  Future<void> _submitCode() async {
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final ok = await ref.read(keyBackupServiceProvider).recoverWithCode(
            uid: widget.authUser.uid,
            code: _enteredCode,
            passwordKey: ref.read(pendingPasswordKeyProvider),
          );
      if (!mounted) return;
      if (ok) {
        _clearPassword();
        NotelyHaptics.success();
        setState(() => _opened = true);
        // A moment to see the lock open, then the notes.
        if (!NotelyMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted) setState(() => _phase = _Phase.ready);
      } else {
        NotelyHaptics.error();
        setState(() => _codeError = "That recovery code didn't match. Check each group and try again.");
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) setState(() => _codeError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _recoveryCode ?? ''));
    NotelyHaptics.light();
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  /// The phone's share sheet: a password manager, Files, a print.
  Future<void> _shareCode() async {
    NotelyHaptics.light();
    await SharePlus.instance.share(ShareParams(
      subject: 'Notely recovery code',
      text: 'Notely recovery code for ${widget.authUser.email}:\n${_recoveryCode ?? ''}\n\n'
          'Keep this private. It unlocks your encrypted notes.',
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.ready) return widget.child;
    final notely = NotelyTheme.of(context);

    final body = switch (_phase) {
      _Phase.loading => const Center(child: CircularProgressIndicator()),
      _Phase.error => _Panel(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't unlock your notes",
          message: 'Check your connection and try again.',
          children: [
            NotelyPrimaryButton(label: 'Try again', onPressed: _prepare),
            NotelySecondaryButton(label: 'Sign out', onPressed: () => ref.read(authServiceProvider).logOut()),
          ],
        ),
      _Phase.showCode => _Page(
          children: [
            const DeskTitle('Your recovery', 'key.'),
            const DeskSubtitle(
              'Your notes are end-to-end encrypted. On a new phone, or after a password reset, '
              "this code unlocks them. We can't recover it for you.",
            ),
            RecoveryKeyCard(code: _recoveryCode ?? '', caption: widget.authUser.email),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: NotelySecondaryButton(
                  label: _copied ? 'Copied' : 'Copy code',
                  leading: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
                  onPressed: _copyCode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NotelySecondaryButton(
                  label: 'Save or share',
                  leading: const Icon(Icons.ios_share_rounded, size: 18),
                  onPressed: _shareCode,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _codeSaved,
              onChanged: (value) {
                NotelyHaptics.select();
                setState(() => _codeSaved = value ?? false);
              },
              title: const Text("I've saved this code somewhere safe"),
              subtitle: const Text('A password manager is ideal.'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),
            NotelyPrimaryButton(
              label: 'Continue',
              onPressed: _codeSaved ? () => setState(() => _phase = _Phase.ready) : null,
            ),
          ],
        ),
      _Phase.enterCode => _Page(
          children: [
            UnlockPadlock(open: _opened),
            const SizedBox(height: 4),
            const DeskTitle('Unlock your', 'notes.'),
            const DeskSubtitle(
              'This device needs your recovery code to unlock your encrypted notes. '
              'You saved it when you first set up Notely.',
            ),
            Semantics(
              label: 'Recovery code',
              child: RecoveryCodeBoxes(
                key: _boxes,
                enabled: !_busy && !_opened,
                error: _codeError != null,
                onChanged: (code) => setState(() {
                  _enteredCode = code;
                  _codeError = null;
                }),
                onSubmitted: _submitCode,
              ),
            ),
            if (_codeError != null) ...[
              const SizedBox(height: 10),
              Text(_codeError!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.danger)),
            ],
            const SizedBox(height: 18),
            NotelyPrimaryButton(label: 'Unlock', loading: _busy, onPressed: _opened ? null : _submitCode),
            const SizedBox(height: 10),
            NotelySecondaryButton(
              label: 'Paste code',
              leading: const Icon(Icons.content_paste_rounded, size: 18),
              onPressed: _busy || _opened ? null : () => _boxes.currentState?.paste(),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => ref.read(authServiceProvider).logOut(),
                style: TextButton.styleFrom(foregroundColor: notely.text2),
                child: const Text('Sign out'),
              ),
            ),
          ],
        ),
      _Phase.ready => const SizedBox.shrink(),
    };

    return Scaffold(backgroundColor: notely.bg, body: SafeArea(child: body));
  }
}

/// A scrolling, width-limited page for the recovery code screens.
class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.message,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
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
                  child: Icon(icon, size: 22, color: notely.violet),
                ),
              ),
              const SizedBox(height: 24),
              NotelyHeading(title: title, subtitle: message),
              const SizedBox(height: 32),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
