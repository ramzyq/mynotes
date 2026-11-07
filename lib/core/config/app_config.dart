class AppConfig {
  /// Firebase Hosting domain of the ramzyqnotes project. Share links and
  /// password reset links point here (see hosting/public). Keep in sync with
  /// the Android intent filter (AndroidManifest.xml), assetlinks.json, and
  /// the Firebase Auth email action URL.
  final String shareDomain = 'ramzyqnotes.web.app';

  const AppConfig();
}

const appConfig = AppConfig();

/// Custom URL scheme the hosted pages' "Open in Notely" buttons use. Works
/// without domain verification (Android App Links / iOS Universal Links).
/// Declared in AndroidManifest.xml and ios/Runner/Info.plist.
const appScheme = 'notely';
