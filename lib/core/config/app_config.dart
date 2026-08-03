class AppConfig {
  /// Root domain for share links and Universal/App Links.
  ///
  /// HUMAN INPUT REQUIRED: set this to the real domain you own before
  /// deploying Tasks 10 and 11, and keep it in sync with the Android
  /// intent-filter, iOS entitlements, and hosting/.well-known files.
  final String shareDomain = 'mynotes.example.com';

  const AppConfig();
}

const appConfig = AppConfig();
