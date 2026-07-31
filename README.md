# Note Log

A privacy-first notes app built with Flutter and Firebase, featuring end-to-end encryption, biometric lock, voice notes, OCR capture, spaced repetition, and real-time collaboration.

## Features

- **End-to-end encryption** — All notes encrypted with AES-256-GCM before leaving your device. Per-note keys wrapped with a Master Key derived from your password. Firebase never sees plaintext.
- **Per-note lock** — Lock individual notes behind biometric (fingerprint/face) or a numeric PIN. Failed PIN attempts trigger a 30-second cooldown after 3 tries.
- **Firebase security rules** — Production-hardened Firestore and Storage rules. Users can only access their own data. Collaborator access is explicitly granted per note.
- **Client-side search** — Full-text search powered by SQLite FTS5. Works with encrypted notes (index rebuilt from decrypted content).
- **OCR from photo** — Extract text from images using on-device ML Kit text recognition. No images leave your device.
- **Voice-to-note** — Record audio and get on-device speech-to-text transcription. Original audio file retained as an attachment.
- **Location-tagged notes** — Attach coordinates to notes with one tap. Reverse-geocoded to a readable place name. Privacy-respecting (opt-in per note, not live-tracked).
- **Wiki-style [[links]]** — Link notes together with `[[Note Title]]` syntax. Autocomplete suggestions. Backlinks view shows which notes reference the current one.
- **Spaced repetition / flashcards** — Flag notes as study material. Review with SM-2 spaced repetition algorithm. Daily review notifications.
- **Version history** — Automatic snapshots on each save (rate-limited). Restore any previous version. Up to 50 versions per note.
- **Real-time collaboration** — Share notes with other users via E2EE. Each collaborator gets the note key encrypted with their public key. Comments on shared notes.
- **Context switcher** — Organize notes with tags. Filter to a focused view per project or topic.
- **Self-destructing notes** — Set a destruction date or mark as read-once. Note is permanently deleted at the trigger point.
- **Dark theme** — Calm, dark workspace for focused writing. Light theme also available.

## Privacy & Security

Note Log is designed with privacy as a default, not an afterthought.

| Feature | Security Model |
|---------|---------------|
| Note content | AES-256-GCM encrypted on-device before sync |
| Encryption keys | Derived via PBKDF2 from your password; stored in OS keychain |
| Search | Client-side only (SQLite FTS5 index from decrypted notes) |
| OCR / Voice | Runs entirely on-device — no data sent to servers |
| Location | Opt-in per note, captured once, not live-tracked |
| Collaboration | E2EE — note key encrypted per collaborator; server never sees plaintext |
| Authentication | Firebase Auth (email/password + Google Sign-In) |
| File storage | Firebase Storage, access controlled by security rules |

## Tech Stack

- **Framework:** Flutter (Dart)
- **State management:** Riverpod
- **Backend:** Firebase (Firestore, Auth, Storage, Analytics)
- **Local database:** Drift (SQLite with FTS5)
- **Encryption:** `cryptography` (AES-256-GCM, PBKDF2)
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

# Generate drift database code
dart run build_runner build --delete-conflicting-outputs

# Run on your device/emulator
flutter run
```

### Firebase Security Rules

Deploy the versioned rules:

```bash
firebase deploy --only firestore,storage
```

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
│   ├── db/                       # Drift database, tables
│   ├── encryption/               # CryptoService, KeyManager
│   ├── error/                    # Error handling
│   └── providers/                # Global Riverpod providers
├── features/
│   ├── auth/                     # Login, register, verify email views
│   ├── capture/                  # OCR, voice, location features
│   ├── collaboration/            # Shared notes, comments
│   ├── lock/                     # Per-note biometric/PIN lock
│   ├── notes/                    # Note model, service, editor, home views
│   ├── settings/                 # Theme toggle, app settings
│   └── study/                    # Spaced repetition / flashcards
├── firestore.rules               # Firestore security rules
├── storage.rules                 # Storage security rules
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
