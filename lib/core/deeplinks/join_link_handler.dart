import 'package:mynotes/core/config/app_config.dart';

class JoinLinkHandler {
  /// Share tokens are base62 (ShareLinkToken, 22 characters). Anything else
  /// is refused before it reaches Firestore: a decoded `/` would otherwise
  /// turn `shareLinks/<token>` into a path into another collection.
  static final _token = RegExp(r'^[A-Za-z0-9]{16,64}$');

  /// The share token in `https://<app domain>/join/<token>` or
  /// `notely://join/<token>`; null for anything else, including other hosts.
  static String? tokenFromUri(Uri uri) {
    final List<String> segments;
    if (uri.scheme == appScheme) {
      segments = [uri.host, ...uri.pathSegments];
    } else if (uri.scheme == 'https' && uri.host == appConfig.shareDomain) {
      segments = uri.pathSegments;
    } else {
      return null;
    }
    if (segments.length == 2 && segments[0] == 'join' && _token.hasMatch(segments[1])) {
      return segments[1];
    }
    return null;
  }
}
