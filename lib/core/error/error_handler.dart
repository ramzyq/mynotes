import 'package:flutter/foundation.dart';

typedef ErrorCallback = void Function(Object error, StackTrace stack);

class AppErrorHandler {
  static final AppErrorHandler _instance = AppErrorHandler._();
  factory AppErrorHandler() => _instance;
  AppErrorHandler._();

  ErrorCallback? onError;

  void handle(Object error, StackTrace stack) {
    onError?.call(error, stack);
    if (kDebugMode) {
      debugPrint('AppError: $error\n$stack');
    }
  }

  void init() {
    FlutterError.onError = (details) {
      handle(details.exception, details.stack ?? StackTrace.current);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      handle(error, stack);
      return true;
    };
  }
}
