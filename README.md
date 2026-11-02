# Notely

A privacy-first notes app built with Flutter and Firebase, featuring end-to-end encryption, biometric lock, voice notes, OCR capture, spaced repetition, and real-time collaboration.

## Features

- **End-to-end encryption** — Note titles, bodies, tags, location, links, and comments are encrypted with AES-256-GCM before leaving your device. Each note has its own key, wrapped with your master key. The master key is backed up encrypted under your password and a recovery code, so it survives reinstalls and new devices.
- **Per-note lock** — A PIN lock encrypts the note's key under the PIN, so the note cannot be opened without it; no PIN hash is stored anywhere. A biometric lock hides the note on this device. After 3 wrong PINs a cooldown starts (30 s, doubling each time) and persists across restarts.
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
- **Self-destructing notes** — Set a destruction date, or mark a note read-once so it is deleted when you close it. The note's versions, comments, and share links are deleted with it. Expired notes are removed by the app when it runs; a server-side TTL policy is recommended for guaranteed deletion.
- **Dark theme** — Calm, dark workspace for focused writing. Light theme also available.

## Privacy & Security

Notely is designed with privacy as a default, not an afterthought.

| Feature | Security Model |
|---------|---------------|
| Note content & metadata | AES-256-GCM on-device; each field is bound to its note via associated data |
| Master key | Random 256-bit key in the OS keychain; backed up encrypted under your password (PBKDF2-SHA256) and a 128-bit recovery code (HKDF). The server cannot open the backup. |
| Search | Client-side only, in memory over decrypted notes |
| OCR / Voice | Runs entirely on-device — no data sent to servers |
| Location | Opt-in per note, captured once, stored encrypted |
| Collaboration | X25519 + HKDF key wrapping per collaborator; key rotation on removal |
| Comments | Encrypted with the note key |
| Authentication | Firebase Auth (email/password + Google Sign-In) |
| File storage | Firebase Storage, access controlled by security rules |

**What is not encrypted:** timestamps, color, pin/archive/lock flags, study scheduling fields, self-destruct time (needed for server queries), collaborator uids, and display names.

**Recovery:** if you sign in on a new device with Google, or after resetting your password, Notely asks for your recovery code. Without the code (or your current password), encrypted notes cannot be recovered by anyone, including us.

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

### Firebase Security Rules

Deploy the versioned rules:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
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
