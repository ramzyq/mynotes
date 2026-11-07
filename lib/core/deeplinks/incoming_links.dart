import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/config/app_config.dart';

/// Links that open the app: share links and password reset links, from the
/// app's domain (App Links / Universal Links) or the `notely://` scheme the
/// hosted pages fall back to. app_links also replays the link that launched
/// the app. Overridden in tests.
final incomingLinksProvider = Provider<Stream<Uri>>((ref) => AppLinks().uriLinkStream);

/// What an incoming link asks the app to do.
sealed class IncomingLink {
  const IncomingLink();

  static IncomingLink? parse(Uri uri) {
    if (!_isOurs(uri)) return null;
    final segments = uri.scheme == appScheme ? [uri.host, ...uri.pathSegments] : uri.pathSegments;
    if (segments.length == 2 && segments[0] == 'auth' && segments[1] == 'action') {
      return uri.queryParameters['mode'] == 'resetPassword' && (uri.queryParameters['oobCode'] ?? '').isNotEmpty
          ? PasswordResetIncomingLink(uri)
          : null;
    }
    if (segments.length == 2 && segments[0] == 'join' && segments[1].isNotEmpty) {
      return JoinIncomingLink(uri);
    }
    return null;
  }

  static bool _isOurs(Uri uri) =>
      uri.scheme == appScheme || (uri.scheme == 'https' && uri.host == appConfig.shareDomain);
}

/// A share link (`/join/<token>`).
class JoinIncomingLink extends IncomingLink {
  const JoinIncomingLink(this.uri);
  final Uri uri;
}

/// A password reset link from the reset email (`/auth/action?mode=resetPassword`).
class PasswordResetIncomingLink extends IncomingLink {
  const PasswordResetIncomingLink(this.uri);
  final Uri uri;
}
