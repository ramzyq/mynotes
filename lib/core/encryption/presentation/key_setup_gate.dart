import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/encryption/key_backup.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/error/error_handler.dart';
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
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() => _phase = _Phase.loading);
    try {
      final password = ref.read(pendingPasswordProvider);
      final result = await ref
          .read(keyBackupServiceProvider)
          .prepare(uid: widget.authUser.uid, password: password);
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
          // Keep the password: recovery re-wraps the password slot with it.
          setState(() => _phase = _Phase.enterCode);
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  void _clearPassword() {
    ref.read(pendingPasswordProvider.notifier).state = null;
  }

  Future<void> _submitCode() async {
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final ok = await ref.read(keyBackupServiceProvider).recoverWithCode(
            uid: widget.authUser.uid,
            code: _codeController.text,
            password: ref.read(pendingPasswordProvider),
          );
      if (!mounted) return;
      if (ok) {
        _clearPassword();
        setState(() => _phase = _Phase.ready);
      } else {
        setState(() => _codeError = "That recovery code didn't match. Check it and try again.");
      }
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) setState(() => _codeError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      _Phase.showCode => _Panel(
          icon: Icons.key_rounded,
          title: 'Save your recovery code',
          message: 'Your notes are end-to-end encrypted. If you sign in on a new '
              "device or reset your password, you'll need this code to unlock "
              "them. We can't recover it for you.",
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: notely.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: notely.border),
              ),
              child: SelectableText(
                _recoveryCode ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 16,
                  height: 1.5,
                  letterSpacing: 1,
                  color: notely.text,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy code'),
                onPressed: () => Clipboard.setData(ClipboardData(text: _recoveryCode ?? '')),
              ),
            ),
            CheckboxListTile(
              value: _codeSaved,
              onChanged: (value) => setState(() => _codeSaved = value ?? false),
              title: const Text("I've saved this code somewhere safe"),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            NotelyPrimaryButton(
              label: 'Continue',
              onPressed: _codeSaved ? () => setState(() => _phase = _Phase.ready) : null,
            ),
          ],
        ),
      _Phase.enterCode => _Panel(
          icon: Icons.lock_reset_rounded,
          title: 'Enter your recovery code',
          message: 'This device needs your recovery code to unlock your '
              'encrypted notes. You saved it when you first set up Notely.',
          children: [
            TextField(
              controller: _codeController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'JetBrains Mono'),
              decoration: InputDecoration(
                labelText: 'Recovery code',
                hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XX',
                errorText: _codeError,
              ),
              onSubmitted: (_) => _busy ? null : _submitCode(),
            ),
            NotelyPrimaryButton(label: 'Unlock', loading: _busy, onPressed: _submitCode),
            NotelySecondaryButton(label: 'Sign out', onPressed: () => ref.read(authServiceProvider).logOut()),
          ],
        ),
      _Phase.ready => const SizedBox.shrink(),
    };

    return Scaffold(backgroundColor: notely.bg, body: SafeArea(child: body));
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
