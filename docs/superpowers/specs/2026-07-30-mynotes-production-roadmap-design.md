# Production Roadmap for MyNotes — Design Spec

## Overview

MyNotes is a Flutter + Firebase notes app being taken to production. The core differentiator is combining **E2EE by default**, **collaboration**, and **rich capture/study tools** in a single app — something no major player does today.

This spec covers the full architecture, all feature designs, and the implementation order.

## Architecture

### Current State
- Flat folder structure (`lib/services/`, `lib/views/`, `lib/widgets/`)
- Raw `setState` + `StreamBuilder` (no state management library)
- Static factory coupling (`AuthService.firebase()`, `NotesService.instance()`)
- Direct Firestore access in `NotesService`

### Target Architecture

```
lib/
├── core/
│   ├── encryption/          # E2EE key management, crypto ops
│   ├── auth/                # Auth service (already exists, move here)
│   ├── db/                  # Local database (SQLite/Hive for offline + FTS)
│   └── models/              # Shared data models
├── features/
│   ├── notes/
│   │   ├── data/            # NotesRepository (Firestore + local)
│   │   ├── domain/          # Note model, use cases
│   │   └── presentation/    # Home view, editor view, widgets
│   ├── auth/                # Login, register, verify email views
│   ├── capture/             # OCR, voice, location features
│   ├── study/               # Spaced repetition / flashcards
│   ├── collaboration/       # Shared notes, comments
│   └── settings/            # App settings, context switcher
└── app.dart                 # App entry, theme, routing
```

### State Management
**Riverpod** — lightweight, compile-safe, testable. Handles dependency injection natively via providers. No boilerplate like BLoC.

### Key Libraries
| Package | Purpose | Justification |
|---------|---------|---------------|
| `flutter_riverpod` | State management + DI | Lightweight, testable, no codegen |
| `drift` | Local storage + FTS index | Offline support, client-side full-text search via SQLite FTS5 |
| `flutter_secure_storage` | Key material storage | OS keychain/keystore for E2EE keys |
| `cryptography` | AES-256-GCM + PBKDF2 | On-device encryption; maintained by dint.dev, pure Dart |
| `google_mlkit_text_recognition` | OCR | On-device, no network |
| `speech_to_text` / `record` | Voice transcription + recording | On-device STT |
| `geolocator` / `geocoding` | Location capture | One-time, not live tracking |
| `flutter_map` | Map previews | OpenStreetMap, no API key |
| `local_auth` | Biometric check | OS biometric prompt |
| `flutter_local_notifications` | Study reminders | Local notifications |

**No new dependencies for:** wiki links, spaced repetition SM-2, version history, context switcher, collaboration — these are pure logic + Firestore queries.

## E2EE Design

### Key Hierarchy
```
Master Key (derived from user's password via PBKDF2)
  └── stored in flutter_secure_storage (platform keychain)
  └── used to wrap/unwrap Note Keys
        └── Each note has a unique AES-256-GCM key
              └── Encrypts content + title
              └── Wrapped Note Key stored in Firestore user document
              └── For shared notes: Note Key encrypted with each collaborator's public key
```

### Encryption Flow
1. On first login: derive Master Key from password via PBKDF2 → persist encrypted Master Key blob in `flutter_secure_storage`
2. On subsequent logins: load encrypted blob from `flutter_secure_storage`, re-derive in-memory Master Key
3. On note save: generate random Note Key → AES-256-GCM encrypt content → wrap Note Key with Master Key → store ciphertext + wrapped key in Firestore
4. On note open: unwrap Note Key → decrypt content → display
5. On password change (detected via Firebase Auth reload): re-wrap all Note Keys with new Master Key derived from new password
6. On app background >5 min: clear in-memory keys, require re-auth on foreground

### Client-Side Search
- On app start: decrypt all notes → build FTS index in local SQLite (drift)
- On search: query local FTS index (sub-millisecond for <10K notes)
- On note create/update: update FTS index
- Full re-index on password change or first login after new device

### Shared Notes (E2EE Collaboration)
- Each note has an `encryptedKeys: Map<userId, String>` field
- Key for collaborator: Note Key encrypted with collaborator's public key
- Public/private keypair derived from each user's Master Key
- Access control enforced by Firestore rules (array-contains check on `collaborators`)
- Server never sees plaintext — only encrypted blobs and key-wrapped ciphertext

## Data Model Changes

### Note (Firestore Document)
```
users/{userId}/notes/{noteId}
{
  // Existing
  title: String,           // encrypted
  content: String,         // encrypted
  colorIndex: int,         // plaintext
  isPinned: bool,          // plaintext
  createdAt: Timestamp,    // plaintext
  updatedAt: Timestamp,    // plaintext

  // E2EE
  encryptedContent: String,         // base64 ciphertext
  encryptedTitle: String,           // base64 ciphertext
  wrappedKey: Map<String, String>,  // {masterKeyVersion: encryptedNoteKey}
  encryptionVersion: int,           // key derivation version

  // Per-note lock
  isLocked: bool,                   // plaintext
  pinHash: String?,                 // hashed PIN (if not using biometric)
  pinSalt: String?,                 // PBKDF2 salt for PIN

  // Self-destruct
  selfDestructAt: Timestamp?,       // plaintext
  selfDestructOnRead: bool,         // plaintext

  // Collaboration
  collaborators: List<String>?,     // [uid1, uid2] — plaintext
  encryptedKeys: Map<String, String>?, // {uid: encryptedNoteKey}
  sharedBy: String?,                // uid of sharer
  sharedAt: Timestamp?,

  // Wiki links
  links: List<String>?,             // [noteId1, noteId2] — plaintext

  // Spaced repetition
  isStudyMaterial: bool,
  studyDueAt: Timestamp?,
  studyInterval: int?,
  studyEaseFactor: double?,
  studyRepetitions: int?,

  // Location
  latitude: double?,
  longitude: double?,

  // Tags / Context
  tags: List<String>?,              // plaintext

  // Local-only
  localOnly: bool,                  // plaintext
}
```

### Comment (Firestore Subcollection)
```
users/{uid}/notes/{noteId}/comments/{commentId}
{
  authorUid: String,
  authorName: String,
  content: String,        // plaintext (comments are collaborative by nature)
  createdAt: Timestamp,
}
```

### Note Version (Firestore Subcollection)
```
users/{uid}/notes/{noteId}/versions/{versionId}
{
  encryptedContent: String,
  encryptedTitle: String,
  versionNumber: int,
  createdAt: Timestamp,
}
```

## Feature Designs

### 1. Per-Note Biometric/PIN Lock
- `local_auth` for biometric prompt
- PIN hashed with PBKDF2 (10K iterations), stored as `pinHash` + `pinSalt`
- Locked notes show padlock icon in list; content hidden until authenticated
- 3 failed PIN attempts → 30s cooldown
- Unlock persists for session (until app backgrounded for >5 min)

### 2. Self-Destructing Notes
- Time-based: client-side check on app open/resume compares `selfDestructAt` to now; deletes locally and queues Firestore delete
- Read-once: delete immediately when note editor opens if `selfDestructOnRead` is true; handled client-side
- No cloud function needed — all destruction logic is client-side, works offline
- Irreversible — no recovery after destruction
- Visual indicator (timer icon + countdown) on note card

### 3. Firestore/Storage Security Rules
- `firestore.rules`: `match /users/{userId}/{document=**} { allow read, write: if request.auth != null && request.auth.uid == userId; }`
- Collaborator access: `match /users/{noteOwnerId}/notes/{noteId} { allow read: if request.auth != null && (request.auth.uid == noteOwnerId || resource.data.collaborators.hasAny([request.auth.uid])); }`
- Storage rules mirror auth check
- Rules tests via `@firebase/rules-unit-testing` in CI

### 4. OCR from Photo
- Button in editor toolbar → bottom sheet: "Take Photo" / "Choose from Gallery"
- `image_picker` for capture
- `google_mlkit_text_recognition` for on-device OCR
- Insert extracted text at cursor position
- No images stored permanently

### 5. Voice-to-Note Transcription
- Microphone button → recording UI with waveform
- `record` package for audio capture
- `speech_to_text` for on-device STT
- Transcription inserted as text; audio file attached (stored locally, optionally synced to Firebase Storage)
- Max 5 min recording

### 6. Location-Tagged Notes
- "Add location" button → one-time location permission → store lat/lng
- `flutter_map` for map preview (OpenStreetMap, no API key)
- Reverse geocode on demand via `geocoding` package
- Location captured once per user action — not live-tracked

### 7. Wiki-Style [[Links]] with Backlinks
- Detecting `[[` in content → autocomplete dropdown of note titles
- On save: parse all `[[...]]` → resolve to note IDs → store in `links` array
- Render as tappable inline links
- Backlinks section at bottom of note: query where `links` array contains this note's ID
- Broken links (deleted target) shown with strikethrough style

### 8. Spaced Repetition / Flashcard Mode
- Flag note as study material
- First line = question, rest = answer (or manual split)
- SM-2 algorithm for interval calculation
- "Review" view shows due cards with rate buttons (Again/Hard/Good/Easy)
- Daily notification for due cards

### 9. Version History with Restore
- Subcollection `versions/{versionId}` per note
- Snapshot on each save (rate-limited: 1 per 5 min)
- Max 50 versions per note (oldest pruned)
- List view with timestamps, previews, "Restore" button
- Restore copies selected version's content to current note
- Delete note = delete all versions

### 10. Real-Time Shared Notes
- Owner invites by email (lookup by auth email)
- `collaborators` array + `encryptedKeys` map
- Firestore real-time snapshots for live updates
- Owner can remove collaborators (removes from `collaborators` array + deletes their encrypted key)
- Collaborators cannot delete or re-share
- E2EE ensures server never sees content

### 11. Comment Threads
- Subcollection `comments/{commentId}`
- Flat list (no threading in v1)
- Real-time updates via Firestore snapshots
- Only accessible by note owner + collaborators
- Comments always plaintext (collaborative by nature)
- Author can delete own comment within 24h

### 12. Context Switcher
- Tags (array on note) with CRUD UI
- Context switcher sidebar/bottom sheet showing tags + counts
- Selecting a tag filters the note list
- Focus mode: hides other contexts, disables badges for non-selected tags
- Tags always plaintext (metadata for Firestore `array-contains` queries)

## Encryption Interaction Matrix

| Feature | Works with Encrypted Notes? | Notes |
|---------|---------------------------|-------|
| OCR | Yes | Runs before encryption at capture time |
| Voice transcription | Yes | Transcribes before encryption; audio file encrypted if synced |
| Location | Yes | Coordinates inside encrypted payload |
| Wiki links | Yes | Links array is plaintext (IDs only); title resolution client-side |
| Spaced repetition | Yes | SM-2 metadata plaintext; content decrypted for review |
| Version history | Yes | Each version encrypted with same Note Key |
| Shared notes | Yes | E2EE via per-collaborator key wrapping |
| Comments | Yes | Comments are plaintext (outside note content) |
| Context switcher | Yes | Tags are plaintext |
| Per-note lock | Yes | Lock check occurs before decryption |
| Self-destruct | Yes | Metadata is plaintext; encrypted content destroyed with note |
| Client-side search | Yes | FTS index built from decrypted notes |

## Implementation Order

### Phase 0 — Foundation (augments existing code)
1. Add `flutter_riverpod` + restructure to feature folders
2. Add `drift` for local DB (offline + FTS)
3. Add `flutter_secure_storage`
4. Migrate auth to Riverpod providers
5. Add error handling framework (global error handler, crash reporting)

### Phase 1 — Security (P0)
1. Firestore/Storage security rules + rules tests [#5]
2. E2EE encryption layer (key management, encrypt/decrypt, wrapped keys) [#1]
3. Client-side search (FTS index from decrypted notes)
4. Per-note biometric/PIN lock [#3]

### Phase 2 — Capture (P1)
5. OCR from photo [#6]
6. Voice-to-note transcription [#7]
7. Location-tagged notes [#8]

### Phase 3 — Organization (P1)
8. Wiki-style links with backlinks [#10]
9. Spaced repetition / flashcards [#9]
10. Version history with restore [#11]

### Phase 4 — Collaboration (P2)
11. E2EE shared notes [#13]
12. Comment threads [#14]

### Phase 5 — UX (P2)
13. Context switcher / focus view [#12]

### Every Phase
- Self-destruct [#4] can be added incrementally alongside any phase (small, isolated feature)
- Tests required for every feature before merge
