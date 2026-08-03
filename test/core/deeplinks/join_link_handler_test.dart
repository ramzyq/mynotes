import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/deeplinks/join_link_handler.dart';

void main() {
  group('JoinLinkHandler.tokenFromUri', () {
    test('extracts token from /join/{token}', () {
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/join/abc123')),
        'abc123',
      );
    });

    test('rejects non-join paths', () {
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/other')),
        isNull,
      );
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/')),
        isNull,
      );
    });

    test('rejects missing token', () {
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/join/')),
        isNull,
      );
    });
  });
}
