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
| Authentication | Firebase Auth (email/password + Google Sign-In). Firebase never receives your password, only a secret derived from it (see below). |
| File storage | Firebase Storage, access controlled by security rules |

**What is not encrypted:** timestamps, color, pin/archive/lock flags, study scheduling fields, self-destruct time (needed for server queries), collaborator uids, and display names.

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

- Flutter SDK 3.10+
- A Firebase project with Firestore, Auth, and Storage enabled
- Google Services configuration files:
  - Android: `android/app/google-services.json`
  - iOS: `ios/Runner/GoogleService-Info.plist`

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

### Password reset email

In the Firebase console, open **Authentication → Templates → Password reset** and edit the message so it tells people to **copy the link into Notely instead of opening it** (for example: "Copy this link and paste it into Notely's *Reset password* screen. Don't set your password on the web page."). The app completes the reset itself; a password set on Firebase's hosted page is stored as typed and has to be replaced from the app afterwards.

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
