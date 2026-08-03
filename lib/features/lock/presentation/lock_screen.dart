import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/lock/services/lock_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  final String noteId;
  final String? pinHash;
  final String? pinSalt;
  final Widget child;

  const LockScreen({
    super.key,
    required this.noteId,
    this.pinHash,
    this.pinSalt,
    required this.child,
  });

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _isLocked = true;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final unlockedNotes = ref.watch(unlockedNotesProvider);

    if (!_isLocked || unlockedNotes.contains(widget.noteId)) {
      return widget.child;
    }

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
            'Locked Note',
            style: TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w700, color: notely.text),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, size: 64, color: notely.violet),
                const SizedBox(height: 24),
                Text(
                  'This note is locked',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Instrument Serif',
                    fontSize: 28,
                    color: notely.text,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: GlassButton.custom(
                    onTap: _canAttempt() ? _authenticate : () {},
                    enabled: _canAttempt(),
                    height: 54,
                    glowColor: notely.violet,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fingerprint, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Unlock with biometrics',
                          style: TextStyle(fontFamily: 'Geist', fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.pinHash != null) ...[
                  const SizedBox(height: 16),
                  GlassPasswordField(
                    placeholder: 'Enter PIN',
                    onSubmitted: _verifyPin,
                  ),
                ],
                if (_cooldownUntil != null)
                  const Text('Too many attempts. Try again later.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canAttempt() {
    if (_cooldownUntil == null) return true;
    if (DateTime.now().isAfter(_cooldownUntil!)) {
      _cooldownUntil = null;
      _failedAttempts = 0;
      return true;
    }
    return false;
  }

  Future<void> _authenticate() async {
    final lockService = ref.read(lockServiceProvider);
    final success = await lockService.authenticateWithBiometrics();
    if (success) {
      setState(() => _isLocked = false);
      ref.read(unlockedNotesProvider.notifier).update((set) => {...set, widget.noteId});
    }
  }

  Future<void> _verifyPin(String pin) async {
    if (widget.pinHash == null || widget.pinSalt == null) return;
    final lockService = ref.read(lockServiceProvider);
    final valid = await lockService.verifyPin(
      pin,
      PinHash(hash: widget.pinHash!, salt: widget.pinSalt!),
    );
    if (valid) {
      setState(() => _isLocked = false);
      ref.read(unlockedNotesProvider.notifier).update((set) => {...set, widget.noteId});
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        setState(() => _cooldownUntil = DateTime.now().add(const Duration(seconds: 30)));
      }
    }
  }
}
