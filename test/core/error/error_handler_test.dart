import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/error/error_handler.dart';

void main() {
  test('AppErrorHandler catches errors via callback', () {
    Object? caughtError;
    final handler = AppErrorHandler();
    handler.onError = (error, stack) {
      caughtError = error;
    };

    final testError = Exception('test');
    handler.handle(testError, StackTrace.current);

    expect(caughtError, equals(testError));
  });
}
