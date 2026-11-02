import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_background.dart';
import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

/// Gate in front of a locked note.
///
/// PIN-locked notes are encrypted under the PIN, so the PIN is what decrypts
/// them; the unlocked note is passed to [builder]. Biometric-locked notes are
/// a device privacy screen and are shown once the biometric prompt passes.
class LockScreen extends ConsumerStatefulWidget {
  final String uid;
  final Note note;
  final Widget Function(Note unlocked) builder;

  const LockScreen({
    super.key,
    required this.uid,
    required this.note,
    required this.builder,
  });

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  Note? _unlocked;
  Duration _cooldown = Duration.zero;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  bool get _usesPin => widget.note.hasPinLock;

  @override
  void initState() {
    super.initState();
    _refreshCooldown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshCooldown() async {
    final remaining = await ref.read(lockAttemptStoreProvider).remainingCooldown(widget.note.id);
    if (!mounted) return;
    setState(() => _cooldown = remaining);
    _ticker?.cancel();
    if (remaining > Duration.zero) {
      _ticker = Timer(remaining, _refreshCooldown);
    }
  }

  Future<void> _authenticate() async {
    final success = await ref.read(lockServiceProvider).authenticateWithBiometrics();
    if (success && mounted) setState(() => _unlocked = widget.note);
  }

  Future<void> _verifyPin(String pin) async {
    if (_busy || _cooldown > Duration.zero || pin.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final attempts = ref.read(lockAttemptStoreProvider);
    try {
      final unlocked = await ref
          .read(notesServiceProvider)
          .unlockWithPin(uid: widget.uid, note: widget.note, pin: pin);
      if (!mounted) return;
      if (unlocked != null) {
        await attempts.recordSuccess(widget.note.id);
        if (mounted) setState(() => _unlocked = unlocked);
        return;
      }
      final cooldown = await attempts.recordFailure(widget.note.id);
      if (!mounted) return;
      setState(() => _error = cooldown > Duration.zero ? null : 'Wrong PIN.');
      await _refreshCooldown();
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) setState(() => _error = "Couldn't unlock this note.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatCooldown(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inSeconds} s';
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _unlocked;
    if (unlocked != null) return widget.builder(unlocked);

    final notely = NotelyTheme.of(context);
    final coolingDown = _cooldown > Duration.zero;

    return GlassPage(
      background: const NotelyBackground(),
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: GlassAppBar(
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
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
                  style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 28, color: notely.text),
                ),
                const SizedBox(height: 24),
                if (_usesPin)
                  GlassPasswordField(
                    placeholder: 'Enter PIN',
                    onSubmitted: _verifyPin,
                  )
                else
                  Center(
                    child: GlassButton.custom(
                      onTap: _authenticate,
                      height: 54,
                      glowColor: notely.violet,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fingerprint, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Unlock with biometrics',
                            style: TextStyle(fontFamily: 'Geist', fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_busy) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                if (_error != null)
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                if (coolingDown)
                  Text(
                    'Too many attempts. Try again in ${_formatCooldown(_cooldown)}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: notely.text3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
