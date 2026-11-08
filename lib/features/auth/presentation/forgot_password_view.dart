import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/core/haptics/notely_haptics.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/async_states.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/auth/presentation/desk/auth_desk.dart';
import 'package:mynotes/features/auth/presentation/desk/desk_scenes.dart';
import 'package:mynotes/features/auth/presentation/password_forms.dart';
import 'package:mynotes/features/auth/presentation/web_reset_repair_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/auth/services/resend_cooldown.dart';

/// Reset a forgotten password without Firebase's web page: the email's link
/// is pasted here, and the app sets the new password (as an auth secret).
/// Pops with the account email once the password is set.
///
/// Three steps on the sign-in desk, the notes face-down throughout: the
/// email, the link (a key note rises while it's on its way), and the new
/// password (a fresh note drops in). When it's done, the notes turn face-up.
///
/// Opened from the reset email's link ([initialLink]), it skips straight to
/// choosing the new password.
class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key, this.initialEmail = '', this.initialLink});
  final String initialEmail;
  final String? initialLink;

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  late final TextEditingController _link = TextEditingController(text: widget.initialLink ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _cooldown = CooldownTicker();
  bool _busy = false;

  /// Opened from a reset link (until the user asks for a new one).
  late bool _fromLink = widget.initialLink != null;
  late bool _sent = _fromLink;

  /// The link is in (pasted or typed): on to the new password.
  late bool _linkReady = _fromLink;

  /// Typing the link by hand instead of pasting it.
  bool _typingLink = false;

  /// The new password is set: the account email to sign in with.
  String? _doneEmail;

  /// For a link: the account it resets, once checked, or why it can't be used.
  String? _linkEmail;
  Object? _linkError;

  @override
  void initState() {
    super.initState();
    if (_fromLink) _checkLink();
    _password.addListener(_typed);
    _confirm.addListener(_typed);
  }

  Future<void> _checkLink() async {
    try {
      final email = await ref.read(passwordAccountServiceProvider).emailForReset(_link.text);
      if (mounted) setState(() => _linkEmail = email);
    } catch (error) {
      if (mounted) setState(() => _linkError = error);
    }
  }

  void _requestNewLink() => setState(() {
        _fromLink = false;
        _sent = false;
        _linkReady = false;
        _linkError = null;
        _link.clear();
      });

  bool _matched = false;

  /// The new password note inks a dot per character and stamps "Matches".
  void _typed() {
    final matches = _password.text.length >= PasswordSecretDeriver.minLength && _password.text == _confirm.text;
    if (matches && !_matched) NotelyHaptics.light();
    _matched = matches;
    setState(() {});
  }

  @override
  void dispose() {
    _email.dispose();
    _link.dispose();
    _password.dispose();
    _confirm.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  void _show(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return _show('Enter the email you signed up with.');
    setState(() => _busy = true);
    try {
      await ref.read(passwordAccountServiceProvider).sendResetEmail(email);
      NotelyHaptics.light();
      // Saved in the background: the wait starts on screen straight away.
      unawaited(ref.read(resendCooldownProvider).start(ResendPurpose.reset, email));
      _cooldown.run(ResendCooldown.length);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) _show(passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back to the email step, keeping any wait that's still running.
  Future<void> _changeEmail() async {
    setState(() => _sent = false);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) return _show('Copy the link from the email first, then tap Paste.');
    NotelyHaptics.select();
    setState(() {
      _link.text = text;
      _linkReady = true;
    });
  }

  void _useTypedLink() {
    if (_link.text.trim().isEmpty) return _show('Paste or type the link from the email.');
    setState(() => _linkReady = true);
  }

  Future<void> _setPassword() async {
    final problem = newPasswordProblem(_password.text, _confirm.text);
    if (problem != null) return _show(problem);
    setState(() => _busy = true);
    try {
      final email = await ref
          .read(passwordAccountServiceProvider)
          .completeReset(linkOrCode: _link.text, newPassword: _password.text);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      NotelyHaptics.success();
      setState(() => _doneEmail = email);
    } catch (error) {
      if (mounted) _show(passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _masked(String email) {
    final at = email.indexOf('@');
    if (at < 2) return email;
    final name = email.substring(0, at);
    return '${name[0]}•••${name[name.length - 1]}${email.substring(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final done = _doneEmail != null;
    final checking = _fromLink && _linkEmail == null && _linkError == null;
    final linkBroken = _fromLink && _linkError != null;
    final choosing = !done && _linkReady && !checking && !linkBroken;
    final step = done ? 4 : (choosing ? 3 : (_sent ? 2 : 1));

    return AuthDesk(
      showBack: !done,
      glow: done,
      pose: done
          ? DeskPose.drift
          : choosing
              ? DeskPose.cleared
              : DeskPose.faceDown,
      scene: done
          ? null
          : choosing
              ? NewPasswordNoteScene(length: _password.text.length, matches: _matched)
              : (step == 2 ? const KeyNoteScene() : null),
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Steps(step: step),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
            child: KeyedSubtree(
              key: ValueKey('$step-$checking-$linkBroken-$_typingLink'),
              child: done
                  ? _donePane()
                  : linkBroken
                      ? _brokenLinkPane()
                      : checking
                          ? const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: LoadingState(label: 'Checking the link…'))
                          : switch (step) {
                              1 => _emailPane(),
                              2 => _linkPane(),
                              _ => _passwordPane(),
                            },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DeskTitle('Locked', 'out?'),
        const DeskSubtitle("It happens. We'll email you a reset link, and you'll choose the new password here in the app."),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<int>(
          valueListenable: _cooldown,
          builder: (context, seconds, _) => NotelyPrimaryButton(
            label: seconds > 0 ? 'Send again in ${CooldownTicker.format(seconds)}' : 'Send reset link',
            loading: _busy,
            onPressed: seconds > 0 ? null : _send,
          ),
        ),
        const SizedBox(height: 4),
        _webPageRepair(),
      ],
    );
  }

  Widget _linkPane() {
    final notely = NotelyTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DeskTitle('Check your', 'inbox.'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: notely.violetSoft,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: notely.violetSoft2),
          ),
          child: Row(children: [
            Expanded(
              child: Text.rich(
                TextSpan(text: 'Sent to ', children: [
                  TextSpan(text: _masked(_email.text.trim()), style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
                style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text),
              ),
            ),
            TextButton(onPressed: _busy ? null : _changeEmail, child: const Text('Change')),
          ]),
        ),
        const SizedBox(height: 10),
        Text(
          "Open the link on this phone and we'll jump straight to the next step. Or copy it and paste it here.",
          style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2),
        ),
        const SizedBox(height: 12),
        if (_typingLink) ...[
          TextField(
            controller: _link,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Reset link from the email'),
            onSubmitted: (_) => _useTypedLink(),
          ),
          const SizedBox(height: 10),
          NotelyPrimaryButton(label: 'Continue', onPressed: _useTypedLink),
        ] else ...[
          NotelySecondaryButton(
            label: 'Paste the link',
            leading: const Icon(Icons.content_paste_rounded, size: 18),
            onPressed: _busy ? null : _paste,
          ),
          Align(
            child: TextButton(onPressed: () => setState(() => _typingLink = true), child: const Text('Type it instead')),
          ),
        ],
        const SizedBox(height: 6),
        _WebPageWarning(),
        const SizedBox(height: 4),
        ValueListenableBuilder<int>(
          valueListenable: _cooldown,
          builder: (context, seconds, _) => Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("Didn't get it?", style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text2)),
              TextButton(
                onPressed: _busy || seconds > 0 ? null : _send,
                child: Text(seconds > 0 ? 'Send again in ${CooldownTicker.format(seconds)}' : 'Send again'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _passwordPane() {
    final notely = NotelyTheme.of(context);
    final strength = passwordStrength(_password.text, PasswordSecretDeriver.minLength);
    const why = "It's set here, in the app, so your notes stay end-to-end encrypted.";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DeskTitle('A new', 'password.'),
        DeskSubtitle(_linkEmail == null ? why : 'For $_linkEmail. $why'),
        NotelyPasswordField(
          controller: _password,
          label: 'New password',
          enabled: !_busy,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 8),
        StrengthMeter(strength: strength, empty: notely.border, danger: notely.danger, ok: const Color(0xFFE5B548), good: notely.success),
        const SizedBox(height: 5),
        Text(
          _password.text.isEmpty
              ? 'At least ${PasswordSecretDeriver.minLength} characters.'
              : const ['', 'Too short', 'Okay', 'Good', 'Strong'][strength],
          style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: notely.text3),
        ),
        const SizedBox(height: 10),
        NotelyPasswordField(
          controller: _confirm,
          label: 'Confirm new password',
          enabled: !_busy,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _setPassword(),
        ),
        const SizedBox(height: 14),
        NotelyPrimaryButton(label: 'Set new password', loading: _busy, onPressed: _setPassword),
        if (!_fromLink) _webPageRepair(),
      ],
    );
  }

  Widget _brokenLinkPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DeskTitle('That link', 'expired.'),
        const SizedBox(height: 8),
        PasswordFormNote(passwordErrorMessage(_linkError!)),
        const SizedBox(height: 16),
        NotelyPrimaryButton(label: 'Send a new link', onPressed: _requestNewLink),
      ],
    );
  }

  Widget _donePane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DeskTitle("You're back", 'in.'),
        const DeskSubtitle('Your password is changed and your notes are just as you left them.'),
        NotelyPrimaryButton(label: 'Sign in', onPressed: () => Navigator.of(context).pop(_doneEmail)),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Your email is filled in for you.',
            style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: NotelyTheme.of(context).text3),
          ),
        ),
      ],
    );
  }

  Widget _webPageRepair() {
    return TextButton(
      onPressed: _busy
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WebResetRepairView(initialEmail: _email.text.trim()),
              )),
      child: const Text('Already set a new password on the web page?'),
    );
  }
}

/// "Step 2 of 3", with a bar per step.
class _Steps extends StatelessWidget {
  const _Steps({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Row(children: [
      for (var i = 1; i <= 3; i++) ...[
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: i == step ? 34 : 22,
          height: 6,
          decoration: BoxDecoration(
            color: i == step ? notely.violet : (i < step ? notely.violet.withValues(alpha: 0.55) : notely.border),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
      ],
      const Spacer(),
      Text(step > 3 ? 'Done' : 'Step $step of 3', style: TextStyle(fontFamily: 'Geist', fontSize: 11.5, color: notely.text3)),
    ]);
  }
}

/// Firebase's own reset page would set the password where the app can't
/// re-wrap the key, so the notes would no longer open with it.
class _WebPageWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFE9D9B4) : const Color(0xFF6B4A0F);
    final edge = dark ? const Color(0x59E5B548) : const Color(0x59B47814);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: edge.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: edge),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: ink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "If a web page asks for a new password, don't use it. Set it here so your notes stay encrypted.",
            style: TextStyle(fontFamily: 'Geist', fontSize: 12, height: 1.4, color: ink),
          ),
        ),
      ]),
    );
  }
}
