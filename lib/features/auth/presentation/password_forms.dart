import 'package:flutter/material.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';

/// What to tell the user when a password flow fails.
String passwordErrorMessage(Object error) => switch (error) {
      PasswordTooShortException() =>
        'Use at least ${PasswordSecretDeriver.minLength} characters for your new password.',
      WrongPasswordAuthException() => "That password isn't right.",
      InvalidResetCodeAuthException() =>
        "That reset link isn't valid any more. Send yourself a new one.",
      TooManyRequestsAuthException() => 'Too many attempts. Try again later.',
      InvalidCredentialAuthException() => 'Enter a valid email address.',
      PasswordBackupNotUpdatedException() =>
        "Your password was changed, but your key backup couldn't be updated. "
            'Sign out and back in on this device to finish.',
      _ => 'Something went wrong. Please try again.',
    };

/// Checks a new password and its confirmation; returns a message or null.
String? newPasswordProblem(String password, String confirmation) {
  if (password.length < PasswordSecretDeriver.minLength) {
    return 'Use at least ${PasswordSecretDeriver.minLength} characters for your new password.';
  }
  if (password != confirmation) return "The passwords don't match.";
  return null;
}

/// Scrolling, width-limited column used by the password screens.
class PasswordFormBody extends StatelessWidget {
  const PasswordFormBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ),
    );
  }
}

/// A short explanatory paragraph in the secondary text style.
class PasswordFormNote extends StatelessWidget {
  const PasswordFormNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Geist',
        fontSize: 14,
        height: 1.5,
        color: NotelyTheme.of(context).text2,
      ),
    );
  }
}
