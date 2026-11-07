import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/password_secrets.dart';

void main() {
  final deriver = PasswordSecretDeriver(iterations: 1000);

  test('the auth secret does not contain or equal the password', () async {
    final s = await deriver.derive(email: 'maya@example.com', password: 'correct horse');
    expect(s.authSecret, isNot(contains('correct horse')));
    expect(s.authSecret.length, greaterThanOrEqualTo(40));
    expect(s.backupKey, hasLength(32));
  });

  test('the auth secret and backup key are independent values', () async {
    final s = await deriver.derive(email: 'maya@example.com', password: 'correct horse');
    expect(s.authSecret, isNot(contains(String.fromCharCodes(s.backupKey))));
    final again = await deriver.derive(email: 'maya@example.com', password: 'correct horse');
    expect(again.backupKey, s.backupKey, reason: 'deterministic, so any device can sign in');
    expect(again.authSecret, s.authSecret);
  });

  test('email is normalized, and salts the derivation', () async {
    final a = await deriver.derive(email: ' Maya@Example.com ', password: 'pw-123456');
    final b = await deriver.derive(email: 'maya@example.com', password: 'pw-123456');
    final other = await deriver.derive(email: 'sam@example.com', password: 'pw-123456');
    expect(a.authSecret, b.authSecret);
    expect(other.authSecret, isNot(a.authSecret));
    expect(other.backupKey, isNot(a.backupKey));
  });

  test('a different password gives different secrets', () async {
    final a = await deriver.derive(email: 'maya@example.com', password: 'pw-123456');
    final b = await deriver.derive(email: 'maya@example.com', password: 'pw-123457');
    expect(b.authSecret, isNot(a.authSecret));
    expect(b.backupKey, isNot(a.backupKey));
  });

  test('a password typed with composed or decomposed accents gives the same secrets', () async {
    const composed = 'café crème'; // é and è as single code points
    const decomposed = 'café crème'; // e + combining accent
    expect(composed, isNot(decomposed));
    final a = await deriver.derive(email: 'maya@example.com', password: composed);
    final b = await deriver.derive(email: 'maya@example.com', password: decomposed);
    expect(b.authSecret, a.authSecret);
    expect(b.backupKey, a.backupKey);
  });

  test('defaults to OWASP-strength PBKDF2', () {
    expect(PasswordSecretDeriver.defaultIterations, greaterThanOrEqualTo(600000));
  });

  test('the auth secret satisfies a strict password policy', () async {
    final s = await deriver.derive(email: 'maya@example.com', password: 'pw-123456');
    expect(s.authSecret, matches(RegExp('[A-Z]')));
    expect(s.authSecret, matches(RegExp('[a-z]')));
    expect(s.authSecret, matches(RegExp('[0-9]')));
    expect(s.authSecret, matches(RegExp(r'[^A-Za-z0-9]')));
  });
}
