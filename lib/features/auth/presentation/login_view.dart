import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/features/auth/presentation/desk/auth_desk.dart';
import 'package:mynotes/features/auth/presentation/desk/logo_moment.dart';
import 'package:mynotes/features/auth/presentation/forgot_password_view.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/presentation/register_view.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart' show AppleSignInCancelledException, GenericAuthException, UserAlreadyExistsAuthException, UserNotFoundAuthException, WrongPasswordAuthException, TooManyRequestsAuthException, GoogleSignInCancelledException;
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:sign_in_button/sign_in_button.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({
    super.key,
  });

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _cardKey = GlobalKey();
  final _shaker = GlobalKey<CardShakerState>();
  bool _isLoading = false;

  /// Shown under the password, for a sign-in the account didn't accept.
  String? _problem;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    _emailFocus.addListener(_focusChanged);
    _passwordFocus.addListener(_focusChanged);
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (_emailFocus.hasFocus || _passwordFocus.hasFocus) NotelyHaptics.select();
    setState(() {});
  }

  /// The notes lean in for the email and turn over for the password.
  DeskPose get _pose => _passwordFocus.hasFocus
      ? DeskPose.faceDown
      : _emailFocus.hasFocus
          ? DeskPose.lean
          : DeskPose.drift;

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// iOS only: Firebase's Apple provider is set up for the native iOS flow.
  static bool get _offerApple => defaultTargetPlatform == TargetPlatform.iOS;

  /// Signed in: the notes become the logo over whatever the app shows next.
  void _celebrate(OverlayState overlay, {required bool faceDown, required Rect? card}) {
    showLogoMoment(overlay, faceDown: faceDown, card: card);
  }

  Future<void> _handleAppleSignIn() async {
    final messenger = ScaffoldMessenger.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final card = globalRectOf(_cardKey);
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithApple();
      // AuthenticationWrapper takes it from here.
      _celebrate(overlay, faceDown: false, card: card);
    } on AppleSignInCancelledException {
      // Cancelled: nothing to say.
    } on UserAlreadyExistsAuthException {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('That email already has a Notely account. Sign in the way you did before.'),
      ));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Apple sign-in failed. Please try again.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final messenger = ScaffoldMessenger.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final card = globalRectOf(_cardKey);
    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Success - AuthenticationWrapper will handle navigation
      _celebrate(overlay, faceDown: false, card: card);
    } on GoogleSignInCancelledException {
      // User cancelled the sign-in flow, nothing to show
    } on GenericAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Google sign-in failed. Please try again.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final email = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => ForgotPasswordView(initialEmail: _email.text.trim()),
    ));
    if (email == null || !mounted) return;
    _email.text = email;
    _password.clear();
    messenger.showSnackBar(
      const SnackBar(content: Text('Password changed. Sign in with your new password.')),
    );
  }

  /// The account turned the sign-in down: say so on the card and shake it.
  void _refuse(String message) {
    if (!mounted) return;
    setState(() => _problem = message);
    NotelyHaptics.error();
    _shaker.currentState?.shake();
  }

  Future<void> _handleLogin() async {
    final email = _email.text.trim();
    final password = _password.text;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _problem = null);

    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your email and password')),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }

    if (password.length < PasswordSecretDeriver.minLength) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password must be at least ${PasswordSecretDeriver.minLength} characters')),
      );
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    final card = globalRectOf(_cardKey);
    final faceDown = _pose == DeskPose.faceDown;
    setState(() => _isLoading = true);

    // Firebase gets only the auth secret; the backup key stays in memory
    // until the key setup gate has used it, then is cleared.
    final secrets = await ref
        .read(passwordSecretDeriverProvider)
        .derive(email: email, password: password);
    if (!mounted) return;
    ref.read(pendingPasswordKeyProvider.notifier).state = secrets.backupKey;
    var signedIn = false;
    try {
      await ref.read(authServiceProvider).logIn(
        email: email,
        password: secrets.authSecret,
      );
      // AuthenticationWrapper routes from here (verify email, key setup, notes).
      signedIn = true;
      _celebrate(overlay, faceDown: faceDown, card: card);
    } on UserNotFoundAuthException {
      _refuse('No account with that email. Create one below.');
    } on WrongPasswordAuthException {
      _refuse('Invalid email or password.');
    } on TooManyRequestsAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Too many attempts. Try again later.')),
      );
    } on GenericAuthException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Login failed. Please try again.')),
      );
    } finally {
      if (!signedIn && mounted) ref.read(pendingPasswordKeyProvider.notifier).state = null;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return AuthDesk(
      pose: _pose,
      cardKey: _cardKey,
      shakerKey: _shaker,
      card: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DeskTitle('Welcome', 'back.'),
            const DeskSubtitle('Your notes are waiting, encrypted on your device.'),
            TextField(
              controller: _email,
              focusNode: _emailFocus,
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _problem == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_problem!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.danger)),
                    ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            NotelyPrimaryButton(label: 'Sign in', loading: _isLoading, onPressed: _handleLogin),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            // Apple first and the same size as Google, per Apple's
            // guidelines for apps offering several sign-in options.
            if (_offerApple) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: SignInButton(
                  Theme.of(context).brightness == Brightness.dark ? Buttons.apple : Buttons.appleDark,
                  text: 'Continue with Apple',
                  elevation: 0,
                  onPressed: _isLoading ? () {} : _handleAppleSignIn,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: SignInButton(
                Buttons.google,
                text: 'Continue with Google',
                elevation: 0,
                onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: notely.borderStrong),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('New to Notely?', style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2)),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const RegisterView()),
                          ),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
