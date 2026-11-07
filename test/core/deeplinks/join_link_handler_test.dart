import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/deeplinks/join_link_handler.dart';

void main() {
  const token = 'AbCdEf0123456789xyzABC'; // 22 base62 characters, like ShareLinkToken
  String? tokenOf(String link) => JoinLinkHandler.tokenFromUri(Uri.parse(link));

  group('JoinLinkHandler.tokenFromUri', () {
    test('reads the token from the app domain and the notely scheme', () {
      expect(tokenOf('https://ramzyqnotes.web.app/join/$token'), token);
      expect(tokenOf('notely://join/$token'), token);
    });

    test('rejects non-join paths and missing tokens', () {
      expect(tokenOf('https://ramzyqnotes.web.app/other'), isNull);
      expect(tokenOf('https://ramzyqnotes.web.app/'), isNull);
      expect(tokenOf('https://ramzyqnotes.web.app/join/'), isNull);
      expect(tokenOf('notely://join/'), isNull);
    });

    test('rejects other hosts and plain http', () {
      expect(tokenOf('https://evil.example/join/$token'), isNull);
      expect(tokenOf('http://ramzyqnotes.web.app/join/$token'), isNull);
    });

    test('rejects tokens outside the token alphabet, including encoded slashes', () {
      expect(tokenOf('notely://join/a%2Fb%2Fc%2Fdddddddddddddddd'), isNull);
      expect(tokenOf('https://ramzyqnotes.web.app/join/${'x' * 10}'), isNull, reason: 'too short');
      expect(tokenOf('https://ramzyqnotes.web.app/join/abc-def_ghi.jklmnopqrs'), isNull);
    });
  });
}
