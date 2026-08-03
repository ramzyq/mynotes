import 'package:flutter/foundation.dart';

enum BootstrapStatus { initializing, ready, failed }

/// Boots the app: initializes Firebase, the glass widget engine, and the
/// global error handler. Exposes retryable failure state instead of crashing.
class BootstrapController extends ChangeNotifier {
  final Future<void> Function() initialize;

  BootstrapController({required this.initialize});

  BootstrapStatus _status = BootstrapStatus.initializing;
  BootstrapStatus get status => _status;

  Object? _error;
  Object? get error => _error;

  String? get errorMessage => _error?.toString();

  Future<void> bootstrap() async {
    _status = BootstrapStatus.initializing;
    _error = null;
    notifyListeners();
    try {
      await initialize();
      _status = BootstrapStatus.ready;
    } catch (e) {
      _status = BootstrapStatus.failed;
      _error = e;
    }
    notifyListeners();
  }
}
