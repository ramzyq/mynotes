import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Locked Note')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: notely.violet),
            const SizedBox(height: 24),
            Text(
              'This note is locked',
              style: TextStyle(
                fontFamily: 'Instrument Serif',
                fontSize: 28,
                color: notely.text,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _canAttempt() ? _authenticate : null,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock with biometrics'),
              style: FilledButton.styleFrom(
                backgroundColor: notely.violet,
                foregroundColor: Colors.white,
              ),
            ),
            if (widget.pinHash != null) ...[
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Enter PIN',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _verifyPin,
              ),
            ],
            if (_cooldownUntil != null)
              Text('Too many attempts. Try again later.'),
          ],
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
