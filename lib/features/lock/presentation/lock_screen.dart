import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/lock/services/biometric_unlock_service.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

/// Gate in front of a locked note.
///
/// PIN-locked notes are encrypted under the PIN, so the PIN (or, if turned on
/// for this device, biometrics releasing the PIN-derived key) is what
/// decrypts them; the unlocked note is passed to [builder]. Older
/// biometric-only locks are a device privacy screen.
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
  final TextEditingController _pinController = TextEditingController();

  bool get _usesPin => widget.note.hasPinLock;

  /// Biometric unlock is set up for this PIN-locked note on this device.
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _refreshCooldown();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    if (!_usesPin || widget.note.pinWrappedKey == null) return;
    final service = ref.read(biometricUnlockServiceProvider);
    final enabled = await service.isEnabled(widget.uid, widget.note.id);
    if (!mounted || !enabled) return;
    setState(() => _biometricEnabled = true);
    await _unlockWithBiometrics();
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(biometricUnlockServiceProvider).unlock(widget.uid, widget.note);
      if (!mounted) return;
      switch (result) {
        case BiometricUnlocked(:final note):
          await ref.read(lockAttemptStoreProvider).recordSuccess(widget.note.id);
          if (mounted) setState(() => _unlocked = note);
        case BiometricCancelled():
          break;
        case BiometricNoLongerAvailable():
          setState(() {
            _biometricEnabled = false;
            _error = 'Biometric unlock was reset on this device. Use your PIN.';
          });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pinController.dispose();
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
      _pinController.clear();
      setState(() => _error = cooldown > Duration.zero ? null : 'Wrong PIN');
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

    return NotelyPage(
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
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
                      child: Icon(Icons.lock_outline, size: 22, color: notely.violet),
                    ),
                  ),
                  const SizedBox(height: 24),
                  NotelyHeading(
                    title: 'Locked note',
                    subtitle: _usesPin
                        ? 'This note is encrypted with its own PIN.'
                        : 'Confirm it is you to open this note.',
                  ),
                  const SizedBox(height: 32),
                  if (_usesPin) ...[
                    TextField(
                      controller: _pinController,
                      autofocus: !_biometricEnabled,
                      enabled: !_busy && !coolingDown,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _verifyPin,
                      style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 20, letterSpacing: 6),
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    NotelyPrimaryButton(
                      label: 'Unlock',
                      loading: _busy,
                      onPressed: coolingDown ? null : () => _verifyPin(_pinController.text),
                    ),
                    if (_biometricEnabled) ...[
                      const SizedBox(height: 12),
                      NotelySecondaryButton(
                        label: 'Use biometrics',
                        leading: Icon(Icons.fingerprint, size: 18, color: notely.text2),
                        onPressed: _busy ? null : _unlockWithBiometrics,
                      ),
                    ],
                  ] else ...[
                    NotelyPrimaryButton(
                      label: 'Unlock with biometrics',
                      icon: Icons.fingerprint,
                      loading: _busy,
                      onPressed: _authenticate,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.danger)),
                    ],
                  ],
                  if (coolingDown) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Too many attempts. Try again in ${_formatCooldown(_cooldown)}.',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        color: notely.text2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
