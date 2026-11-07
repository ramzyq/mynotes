# Notely

A privacy-first notes app built with Flutter and Firebase, featuring end-to-end encryption, biometric lock, voice notes, OCR capture, spaced repetition, and real-time collaboration.

## Features

- **End-to-end encryption** — Note titles, bodies, tags, location, links, and comments are encrypted with AES-256-GCM before leaving your device. Each note has its own key, wrapped with your master key. The master key is backed up encrypted under your password and a recovery code, so it survives reinstalls and new devices.
- **Per-note lock** — A PIN lock encrypts the note's key under the PIN, so the note cannot be opened without it; no PIN hash is stored anywhere. Optionally, the PIN-derived key can also be kept in biometric-protected device storage (Android Keystore with strong biometrics on Android 9+, iOS Keychain bound to the current Face ID/Touch ID set), so the note opens with a fingerprint or face on that device. Biometrics never replace the PIN: it is still required on other devices and after biometric enrollment changes. After 3 wrong PINs a cooldown starts (30 s, doubling each time) and persists across restarts.
- **Firebase security rules** — Users can only access their own data; collaborators can read notes shared with them and comment as themselves. User profiles, share links, and the email lookup can be fetched by id but never listed. Covered by emulator tests in `tests/`.
- **Client-side search** — Search runs in memory over notes decrypted on your device. Nothing searchable is sent to or stored on a server.
- **OCR from photo** — Extract text from images using on-device ML Kit text recognition. No images leave your device.
- **Voice-to-note** — Record audio and get on-device speech-to-text transcription. Original audio file retained as an attachment.
- **Location-tagged notes** — Attach coordinates to notes with one tap. Reverse-geocoded to a readable place name. Privacy-respecting (opt-in per note, not live-tracked).
- **Wiki-style [[links]]** — Link notes together with `[[Note Title]]` syntax. Autocomplete suggestions. Backlinks view shows which notes reference the current one. Links are resolved on-device because titles are encrypted.
- **Spaced repetition / flashcards** — Flag notes as study material. Review with SM-2 spaced repetition algorithm. Daily review notifications.
- **Version history** — An encrypted snapshot is taken on save (at most every 5 minutes). Restoring a version first snapshots the current one, so restores can be undone. Up to 50 versions per note.
- **Collaboration** — Share by email or by link (open or approval-required). Each collaborator gets the note key wrapped for their X25519 public key. Removing a collaborator rotates the note key. Collaborators can read and comment; only the owner edits.
- **Context switcher** — Organize notes with tags. Filter to a focused view per project or topic.
- **Self-destructing notes** — Set a destruction date, or mark a note read-once so it is deleted when you close it. The note's versions, comments, and share links are deleted with it. Expired notes are deleted by the app while it is open; with the Blaze plan, a Firestore TTL policy (usually within 24 hours of expiry) and a Cloud Function make this server-side and remove everything attached to a deleted note. Self-destruct cannot remove copies a collaborator has already decrypted on their own device.
- **Works offline** — Writing, editing, pinning, archiving and trashing work without a connection: changes are saved on the device at once and sync when it's back. Sharing, PIN locks and account changes need a connection and say so.
- **Delete your account** — Account → Delete account removes your notes, their history, comments you posted, share links, join requests and your key backup, then the account itself.
- **Dark theme** — Calm, dark workspace for focused writing. Light theme also available.

## Privacy & Security

Notely is designed with privacy as a default, not an afterthought.

| Feature | Security Model |
|---------|---------------|
| Note content & metadata | AES-256-GCM on-device; each field is bound to its note via associated data |
| Master key | Random 256-bit key in the OS keychain; backed up encrypted under a key derived from your password and under a 128-bit recovery code (HKDF). The server cannot open the backup. |
| Search | Client-side only, in memory over decrypted notes |
| OCR / Voice | Runs entirely on-device — no data sent to servers |
| Location | Opt-in per note, captured once, stored encrypted |
| Collaboration | X25519 + HKDF key wrapping per collaborator; key rotation on removal |
| Comments | Encrypted with the note key |
| Authentication | Firebase Auth (email/password, Google Sign-In, and Sign in with Apple on iOS). Firebase never receives your password, only a secret derived from it (see below). Google and Apple accounts unlock their key backup with the recovery code. |
| File storage | Firebase Storage, access controlled by security rules |

**What is not encrypted:** timestamps, color, pin/archive/lock flags, study scheduling fields, self-destruct time (needed for server queries), collaborator uids, and your profile (display name, email and sharing public key). A profile can be read by any signed-in user who knows your account id, which in practice means people you share notes with; profiles can't be listed or searched. Share-by-email also reveals whether an email has a Notely account.

**Trust in the server for sharing:** when you share, the app encrypts the note key for the recipient's public key as published on their profile. The app doesn't verify that key, so a compromised server could substitute its own and read notes shared after that point. Notes you don't share aren't affected.

**PIN locks** are strong against the server (opening one also needs your master key), but someone holding your unlocked phone with access to its storage could try PINs offline, so new locks need at least 6 digits. The cooldown after wrong PINs is a convenience, not a security boundary.

**Your password never reaches the server.** The app stretches it on your device (PBKDF2-SHA256, 600,000 iterations, salted with your email, after Unicode NFC normalization) and splits the result with HKDF into two independent secrets: an *auth secret*, which is all Firebase Auth ever receives, and a *backup key*, which opens the password slot of your key backup and never leaves the device. Knowing the auth secret does not reveal the backup key, so neither Firebase nor anyone who breaks into it can open your notes with what it stores. What remains is offline guessing: someone holding the auth secret can try candidate passwords, at the full PBKDF2 cost per guess, which is why Notely requires at least 8 characters. **Changing or resetting your password** happens inside the app for the same reason: Firebase's hosted reset page would store the raw password. *Change password* (Account) re-authenticates with the current password's auth secret, sets the new one, and re-wraps the key backup. *Forgot password?* (Sign in) emails a reset link; you paste that link into the app, which sets the new password's auth secret. If you set a password on the web page anyway, *Already set a new password on the web page?* signs in with it once and replaces it with one chosen in the app. Changing the account email is not supported yet: the email salts the derivation, so it would have to update both secrets at once.

**Recovery:** if you sign in on a new device with Google, or after losing your password, Notely asks for your recovery code. Without the code (or your current password), encrypted notes cannot be recovered by anyone, including us.

## Tech Stack

- **Framework:** Flutter (Dart)
- **State management:** Riverpod
- **Backend:** Firebase (Firestore, Auth, Storage, Analytics)
- **Encryption:** `cryptography` (AES-256-GCM, PBKDF2, HKDF, X25519)
- **Key storage:** `flutter_secure_storage`
- **Biometrics:** `local_auth`

## Getting Started

### Prerequisites

- Flutter SDK 3.10+ (CI uses 3.41)
- The `ramzyqnotes` Firebase project (Firestore, Auth, Hosting). Firebase is
  configured from `lib/firebase_options.dart`; Android also reads
  `android/app/google-services.json`. iOS needs no `GoogleService-Info.plist`:
  the Google Sign-In client is set in `ios/Runner/Info.plist`.
- iOS 15.5+ (Firebase and ML Kit), Android 7.0+ (API 24).

### Setup

```bash
# Clone the repository
git clone https://github.com/ramzyq/mynotes.git
cd mynotes

# Install dependencies
flutter pub get

# Run on your device/emulator
flutter run
```

### Hosting, share links and email links

`hosting/public` is deployed to **https://ramzyqnotes.web.app**:

| Path | What it does |
|---|---|
| `/join/<token>` | Share link landing page with an *Open in Notely* button (`notely://join/<token>`). |
| `/auth/action` | Firebase Auth email action handler. Password reset opens the app (no password field, ever); email verification and recovery are applied on the page. |
| `/.well-known/assetlinks.json` | Android App Links verification, so `/join/...` and `/auth/action` open the app directly. |

```bash
firebase deploy --only hosting
```

**Firebase's own email links.** This project can't point Firebase's emails at
`/auth/action`: the console's *Customize action URL* is refused with
`EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` (tried 2026-11-07; Blaze or custom SMTP
might lift it). Emails therefore link to Firebase's page,
`https://ramzyqnotes.firebaseapp.com/__/auth/action`, which asks for a new
password on the web. To keep resets in the app anyway:

- **Android** claims that link with App Links (`firebaseapp.com` serves the same
  hosting site, so the same `assetlinks.json` verifies it). Tapping a reset link
  opens Notely's reset screen; tapping a verification link verifies in the app.
- **iOS and computers** see Firebase's page. Users can copy the link into
  Notely's *Reset password* screen, and an account whose password was set on the
  web is repaired with *Already set a new password on the web page?*. With an
  Apple Team ID, iOS can claim the link the same way.

If the action URL ever becomes changeable, set it to
`https://ramzyqnotes.web.app/auth/action`; the app handles both.

### Firebase Rules, Indexes, and Functions

Deploy the versioned rules and indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Server-side self-destruct requires the Blaze (pay-as-you-go) plan. Once
billing is enabled, add `"ttl": true` to the `selfDestructAt` field override in
`firestore.indexes.json` and redeploy the indexes, then deploy the cleanup
function, which deletes a note's versions, comments, and share links whenever
the note is deleted (by the app, by TTL, or from the console).

```bash
npm --prefix functions install
firebase deploy --only functions
```

To run the function tests locally:

```bash
firebase emulators:exec --only firestore,auth 'npm --prefix functions test'
```

### One-off data migration

Older app versions stored each encrypted note's plaintext title and content
next to the ciphertext. `functions/scripts/maintenance.js` deletes those
fields and backfills the share-by-email index for existing verified accounts.
It needs Admin SDK credentials (a service-account key) and is a dry run
unless `--apply` is passed:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
node functions/scripts/maintenance.js --project ramzyqnotes          # dry run
node functions/scripts/maintenance.js --project ramzyqnotes --apply  # write
```

Copies of the plaintext may remain in Firestore backups or exports made
before the purge.

To run the rules tests locally:

```bash
cd tests
npm install
firebase emulators:exec --only firestore 'npm test'
```

## Launch checklist

Done in the repo: release builds (R8 rules, Crashlytics plugin, checked in CI
for Android and iOS), App Links, the `notely://` scheme, iOS deployment target
and Podfile, iOS Google Sign-In, backup exclusion, hosting with security
headers, explicit loading/error/offline states, in-app account deletion.

Still needed, outside the repo:

- [ ] **Deploy to production** (the app depends on these):

      ```bash
      firebase deploy --only firestore:rules,firestore:indexes,hosting --project ramzyqnotes
      ```

      Rules: report validation, profile deletion, and the author/recipient
      queries account deletion uses. Indexes: two single-field
      collection-group indexes for those queries (they take a few minutes to
      build). Hosting: share link pages, the email action handler, and
      `assetlinks.json`.
- [ ] **Account deletion on the web (Google Play).** Play also wants a web page
      where people can request deletion without the app. It needs a support
      contact (an email address), which isn't decided yet; add a
      `hosting/public/delete-account.html` with the in-app steps and that
      contact, and give Play its URL.
- [ ] **Privacy policy.** Both stores require a public privacy policy URL. The
      *Privacy & Security* section above describes what the app collects and
      encrypts; publish a policy (e.g. `hosting/public/privacy.html`) that you
      have reviewed, and link it in both store listings.
- [ ] **Release signing (Android).** Create an upload key, add a `signingConfigs`
      block in `android/app/build.gradle.kts`, and add the upload key's and
      Play App Signing's SHA-256 fingerprints to
      `hosting/public/.well-known/assetlinks.json` (and their SHA-1 to the
      Firebase Android app for Google Sign-In). Until then release builds are
      signed with the debug key.
- [ ] **Application ID.** `com.flutter.mynotes` (Android) / `com.flutter.mynotes`
      (iOS) is permanent once published. To change it, register the new ID as a
      Firebase app and regenerate `firebase_options.dart` with `flutterfire configure`.
- [ ] **Sign in with Apple (iOS).** In the Firebase console, enable **Authentication →
      Sign-in method → Apple** (the native iOS flow needs no Services ID). The app
      already declares the capability (`ios/Runner/Runner.entitlements`); with
      automatic signing, Xcode/App Store Connect enables it for the App ID. App
      Store guideline 4.8 requires it because the app offers Google sign-in.
- [ ] **Apple Team ID (iOS Universal Links).** Set `DEVELOPMENT_TEAM`, add the
      Associated Domains capability (`applinks:ramzyqnotes.web.app`), and add
      `hosting/public/.well-known/apple-app-site-association` with
      `<TEAMID>.com.flutter.mynotes`. Until then iOS opens links through the
      *Open in Notely* button.
- [ ] **App Check** (Play Integrity / App Attest) once the app is signed for release.
- [ ] Manual test on real devices against production: register, verify email,
      sign out/in, change password, reset password from the email link, share by
      email and by link, biometric unlock, editing in airplane mode (and closing
      the editor while offline), and deleting a test account. Time one sign-in
      on a mid-range Android phone (600k PBKDF2 iterations).

## Project Structure

```
lib/
├── app.dart                      # App entry, routing, theme
├── main.dart                     # Initialization
├── core/
│   ├── auth/models/              # AuthUser model
│   ├── auth/services/            # AuthService, FirebaseAuthProvider
│   ├── encryption/               # CryptoService, KeyManager, KeyBackupService, key setup gate
│   ├── error/                    # Error handling
│   └── providers/                # Global Riverpod providers
├── features/
│   ├── auth/                     # Login, register, verify email views
│   ├── capture/                  # OCR, voice, location features
│   ├── collaboration/            # Shared notes, comments
│   ├── lock/                     # Per-note biometric/PIN lock
│   ├── notes/                    # Note model, service, editor, home views
│   ├── account/                  # Account sheet, archived notes, join requests
│   └── study/                    # Spaced repetition / flashcards
├── firestore.rules               # Firestore security rules
├── storage.rules                 # Storage security rules
├── firestore.indexes.json        # Indexes and the selfDestructAt TTL policy
├── functions/                    # Cloud Function: clean up after deleted notes
└── tests/                        # Firebase rules unit tests
```

## Development

Run the full test suite:

```bash
flutter test
```

Run the analyzer:

```bash
flutter analyze
```

## License

Private project.
