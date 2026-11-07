import 'package:mynotes/core/config/app_config.dart';

class JoinLinkHandler {
  /// The share token in `https://<domain>/join/<token>` or
  /// `notely://join/<token>`.
  static String? tokenFromUri(Uri uri) {
    final List<String> segments;
    if (uri.scheme == appScheme) {
      segments = [uri.host, ...uri.pathSegments];
    } else if (uri.scheme == 'https' || uri.scheme == 'http') {
      segments = uri.pathSegments;
    } else {
      return null;
    }
    if (segments.length == 2 && segments[0] == 'join' && segments[1].isNotEmpty) {
      return segments[1];
    }
    return null;
  }
}
