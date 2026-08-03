class JoinLinkHandler {
  static String? tokenFromUri(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final segments = uri.pathSegments;
    if (segments.length == 2 && segments[0] == 'join' && segments[1].isNotEmpty) {
      return segments[1];
    }
    return null;
  }
}
