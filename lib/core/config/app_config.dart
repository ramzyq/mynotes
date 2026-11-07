class AppConfig {
  /// Firebase Hosting domain of the ramzyqnotes project. Share links and
  /// password reset links point here (see hosting/public). Keep in sync with
  /// the Android intent filter (AndroidManifest.xml), assetlinks.json, and
  /// the Firebase Auth email action URL.
  final String shareDomain = 'ramzyqnotes.web.app';

  /// Where Firebase Auth's own emails link to (`/__/auth/action`). The
  /// project can't change that link (Firebase refuses with
  /// EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED), so the Android app claims it with
  /// App Links instead: this domain serves the same hosting site, including
  /// assetlinks.json.
  final String firebaseAuthDomain = 'ramzyqnotes.firebaseapp.com';

  const AppConfig();
}

const appConfig = AppConfig();

/// Custom URL scheme the hosted pages' "Open in Notely" buttons use. Works
/// without domain verification (Android App Links / iOS Universal Links).
/// Declared in AndroidManifest.xml and ios/Runner/Info.plist.
const appScheme = 'notely';

/// Credit for the third-party artwork the app icon and logo are based on.
/// Shown in the app (Account → About & credits) and to be pasted into the
/// App Store and Play Store descriptions, as the icon's Flaticon licence
/// requires. Use the exact wording Flaticon gives on the icon's download page.
const iconAttribution = 'App icon and logo based on an icon from Flaticon (flaticon.com).';
