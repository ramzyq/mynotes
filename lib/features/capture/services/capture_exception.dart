/// A capture feature (microphone, location) cannot run, with a message the
/// UI can show as-is. [needsSettings] means the user must re-enable it in
/// the system settings (permission permanently denied, or service off).
class CaptureUnavailableException implements Exception {
  final String message;
  final bool needsSettings;

  const CaptureUnavailableException(this.message, {this.needsSettings = false});

  @override
  String toString() => message;
}
