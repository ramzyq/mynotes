import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/config/app_config.dart';
import 'package:mynotes/core/deeplinks/join_link_handler.dart';

/// Links that open the app: share links and email action links (password
/// reset, email verification), from the app's domain, Firebase Auth's own
/// email link domain (Android App Links), or the `notely://` scheme the
/// hosted pages fall back to. app_links also replays the link that launched
/// the app. Overridden in tests.
final incomingLinksProvider = Provider<Stream<Uri>>((ref) => AppLinks().uriLinkStream);

/// What an incoming link asks the app to do.
sealed class IncomingLink {
  const IncomingLink();

  static IncomingLink? parse(Uri uri) {
    if (_isFirebaseAuthLink(uri)) return _emailAction(uri);
    if (!_isOurs(uri)) return null;
    final segments = uri.scheme == appScheme ? [uri.host, ...uri.pathSegments] : uri.pathSegments;
    if (segments.length == 2 && segments[0] == 'auth' && segments[1] == 'action') return _emailAction(uri);
    if (JoinLinkHandler.tokenFromUri(uri) != null) return JoinIncomingLink(uri);
    return null;
  }

  /// An email action link (`?mode=...&oobCode=...`). Android can't filter
  /// links by query, so every mode reaches the app and each needs an answer.
  static IncomingLink? _emailAction(Uri uri) {
    final code = uri.queryParameters['oobCode'] ?? '';
    if (code.isEmpty) return null;
    return switch (uri.queryParameters['mode']) {
      'resetPassword' => PasswordResetIncomingLink(uri),
      'verifyEmail' => VerifyEmailIncomingLink(code),
      _ => const UnsupportedEmailActionIncomingLink(),
    };
  }

  static bool _isOurs(Uri uri) =>
      uri.scheme == appScheme || (uri.scheme == 'https' && uri.host == appConfig.shareDomain);

  /// Firebase Auth's own email link, which the project can't change (see
  /// [AppConfig.firebaseAuthDomain]).
  static bool _isFirebaseAuthLink(Uri uri) =>
      uri.scheme == 'https' && uri.host == appConfig.firebaseAuthDomain && uri.path == '/__/auth/action';
}

/// A share link (`/join/<token>`).
class JoinIncomingLink extends IncomingLink {
  const JoinIncomingLink(this.uri);
  final Uri uri;
}

/// A password reset link from the reset email.
class PasswordResetIncomingLink extends IncomingLink {
  const PasswordResetIncomingLink(this.uri);
  final Uri uri;
}

/// An email verification link: applied in the app.
class VerifyEmailIncomingLink extends IncomingLink {
  const VerifyEmailIncomingLink(this.code);
  final String code;
}

/// Any other email action (recover or change email). The app has no screen
/// for these; the web page handles them.
class UnsupportedEmailActionIncomingLink extends IncomingLink {
  const UnsupportedEmailActionIncomingLink();
}
