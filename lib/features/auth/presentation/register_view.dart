import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/features/auth/presentation/desk/auth_desk.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_note.dart';
import 'package:mynotes/features/auth/presentation/desk/logo_moment.dart';
import 'package:mynotes/features/auth/services/resend_cooldown.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({
    super.key,
  });

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  late final TextEditingController _firstName;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _confirmPassword;
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _cardKey = GlobalKey();
  bool _isLoading = false;

  @override
  void initState() {
    _firstName = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
    _confirmPassword = TextEditingController();
    _passwordFocus.addListener(_focusChanged);
    _confirmFocus.addListener(_focusChanged);
    super.initState();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _passwordFocus.removeListener(_focusChanged);
    _confirmFocus.removeListener(_focusChanged);
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Held while the account is being created: the fields are disabled then,
  /// which drops their focus, and the notes shouldn't turn back over.
  bool? _heldFaceDown;

  bool get _typingPassword => _heldFaceDown ?? (_passwordFocus.hasFocus || _confirmFocus.hasFocus);
  bool _wasTypingPassword = false;

  /// The notes turn over while a password is typed, and back after.
  void _focusChanged() {
    if (!mounted) return;
    if (_typingPassword != _wasTypingPassword) NotelyHaptics.select();
    _wasTypingPassword = _typingPassword;
    setState(() {});
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _handleRegister() async {
    final firstName = _firstName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;
    final messenger = ScaffoldMessenger.of(context);

    if (firstName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    if (password.length < PasswordSecretDeriver.minLength) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least ${PasswordSecretDeriver.minLength} characters')),
      );
      return;
    }

    if (password != confirmPassword) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    final card = globalRectOf(_cardKey);
    final faceDown = _typingPassword;
    NotelyHaptics.medium();
    setState(() {
      _heldFaceDown = faceDown;
      _isLoading = true;
    });

    // Firebase gets only the auth secret; the backup key stays in memory
    // until the key setup gate has used it, then is cleared.
    // Before the try below: a failure here must still stop the spinner.
    final PasswordSecrets secrets;
    try {
      secrets = await ref.read(passwordSecretDeriverProvider).derive(email: email, password: password);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (mounted) {
        setState(() {
          _heldFaceDown = null;
          _isLoading = false;
        });
        messenger.showSnackBar(const SnackBar(content: Text("Couldn't prepare your account on this device. Please try again.")));
      }
      return;
    }
    if (!mounted) return;
    ref.read(pendingPasswordKeyProvider.notifier).state = secrets.backupKey;
    var signedIn = false;
    try {
      await ref.read(authServiceProvider).createUser(
        email: email,
        password: secrets.authSecret,
        displayName: firstName,
      );
      signedIn = true;
      // The one automatic verification email. VerifyEmailView only resends
      // on request, so reopening the app doesn't send another every time.
      try {
        await ref.read(authServiceProvider).sendEmailVerification();
        // Verify email waits a minute before offering to send another.
        unawaited(ref.read(resendCooldownProvider).start(ResendPurpose.verify, email));
      } catch (error, stack) {
        AppErrorHandler().handle(error, stack); // "Send the link again" is there.
      }
      if (!mounted) return;
      // The notes become the logo, with a welcome, over the verify screen.
      showLogoMoment(
        overlay,
        faceDown: faceDown,
        middle: _FreshNotebook(name: firstName),
        card: card,
        welcome: 'Welcome, ${firstName.split(' ').first}.',
      );
      // Signed in now: AuthenticationWrapper shows the verify screen under
      // this one. Pushing another would stack a second copy.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on WeakPasswordAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least ${PasswordSecretDeriver.minLength} characters.')),
      );
    } on UserAlreadyExistsAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('That email is already registered.')),
      );
    } on InvalidCredentialAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
    } on GenericAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Registration failed. Please try again.')),
      );
    } finally {
      if (!signedIn && mounted) ref.read(pendingPasswordKeyProvider.notifier).state = null;
      if (mounted) {
        setState(() {
          _heldFaceDown = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return AuthDesk(
      pose: _typingPassword ? DeskPose.faceDown : DeskPose.drift,
      cardKey: _cardKey,
      showBack: true,
      middleClip: true,
      // The first name writes itself onto the fresh notebook as it's typed.
      middle: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _firstName,
        builder: (context, value, _) => _FreshNotebook(name: value.text),
      ),
      card: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DeskTitle('Start your', 'notebook.'),
            const DeskSubtitle('Your password also protects your encryption key, so choose one you will remember.'),
            TextField(
              controller: _firstName,
              enabled: !_isLoading,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            Focus(
              focusNode: _passwordFocus,
              skipTraversal: true,
              canRequestFocus: false,
              child: NotelyPasswordField(
                controller: _password,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
            ),
            const SizedBox(height: 10),
            Focus(
              focusNode: _confirmFocus,
              skipTraversal: true,
              canRequestFocus: false,
              child: NotelyPasswordField(
                controller: _confirmPassword,
                label: 'Confirm password',
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _handleRegister(),
              ),
            ),
            const SizedBox(height: 18),
            NotelyPrimaryButton(label: 'Create account', loading: _isLoading, onPressed: _handleRegister),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Already have an account?', style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2)),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The fresh notebook on Create account, with the first name written on it.
class _FreshNotebook extends StatelessWidget {
  const _FreshNotebook({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Instrument Serif', fontStyle: FontStyle.italic, fontSize: 22, height: 1.1, color: Color(0xFF1F1B16)),
          ),
          const SizedBox(height: 4),
          const Text('A fresh notebook', style: TextStyle(fontFamily: 'Geist', fontSize: 10, color: Color(0xFF7B7266))),
          const SizedBox(height: 9),
          Container(height: 5, decoration: BoxDecoration(color: deskInk.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(3))),
        ],
      ),
    );
  }
}
