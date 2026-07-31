# Phase 1: Security Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Firestore/Storage security rules with tests, implement E2EE at rest (AES-256-GCM with per-note keys), add client-side full-text search, and add per-note biometric/PIN lock.

**Architecture:** Encryption key hierarchy: Master Key derived from password via PBKDF2 → per-note AES-256-GCM Note Keys wrapped with Master Key. Ciphertext stored in Firestore. Search via drift FTS5 index rebuilt from decrypted notes. Per-note lock gates decryption with biometric or PIN.

**Tech Stack:** `cryptography` package (AES-256-GCM, PBKDF2), `flutter_secure_storage`, `local_auth`, Firebase Emulator Suite + `@firebase/rules-unit-testing`

---

## File Structure Map

### New files to create:
- `firestore.rules` — Firestore security rules
- `storage.rules` — Firebase Storage security rules
- `tests/firestore.rules` — Rules test config
- `tests/storage.rules` — Storage rules test config
- `lib/core/encryption/crypto_service.dart` — AES-256-GCM encrypt/decrypt
- `lib/core/encryption/key_manager.dart` — Master Key derivation, wrapped keys
- `lib/core/encryption/models/encrypted_note.dart` — Encrypted note data model
- `lib/core/encryption/providers/encryption_providers.dart` — Riverpod providers for crypto
- `lib/features/notes/providers/search_provider.dart` — Client-side FTS search provider
- `lib/features/notes/data/local_note_repository.dart` — Combines drift + Firestore
- `lib/features/lock/presentation/lock_screen.dart` — Biometric/PIN prompt overlay
- `lib/features/lock/providers/lock_providers.dart` — Lock state providers
- `lib/features/lock/services/lock_service.dart` — PIN hashing + verification

### Files to modify:
- `pubspec.yaml` — add `cryptography`, `local_auth` deps
- `lib/core/db/tables.dart` — add FTS5 virtual table for search
- `lib/core/db/app_database.dart` — add FTS5 table + search DAO
- `lib/features/notes/data/note.dart` — add encrypted fields
- `lib/features/notes/data/notes_service.dart` — integrate encryption on save/open
- `lib/features/notes/presentation/note_editor_view.dart` — add lock toggle
- `lib/features/notes/presentation/notes_home_view.dart` — lock icon, unlock flow
- `lib/app.dart` — add lock overlay support

### Test files to create:
- `test/core/encryption/crypto_service_test.dart`
- `test/core/encryption/key_manager_test.dart`
- `test/features/lock/lock_service_test.dart`
- `test/features/notes/search/search_test.dart`

---

## Global Constraints

- Never store plaintext encryption keys in Firestore — only wrapped (encrypted) keys.
- Master Key never leaves the device — stored in `flutter_secure_storage`.
- All encryption/decryption is synchronous and runs on the isolate — no main-thread blocking for crypto.
- `flutter analyze` must pass with no issues after each task.
- `flutter test` must pass after each task.
- Firebase rules tests use the Emulator Suite — no production Firestore access during tests.
- PINs are minimum 6 digits, hashed with PBKDF2 (10K iterations) + random salt.

---

### Task 1: Firestore/Storage security rules + rules tests

**Files:**
- Create: `firestore.rules`
- Create: `storage.rules`
- Create: `tests/firestore.rules` (test file)
- Create: `tests/storage.rules` (test file)
- Create: `package.json` — for npm-based rules testing setup (if needed)
- Create: `.github/workflows/firebase-rules.yml` — CI workflow

- [ ] **Step 1: Create firestore.rules**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Own data: full access
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
    }

    // Collaborator access to shared notes
    match /users/{noteOwnerId}/notes/{noteId} {
      allow read: if request.auth != null
        && (request.auth.uid == noteOwnerId
            || resource.data.collaborators.hasAny([request.auth.uid]));
      allow write: if request.auth != null
        && request.auth.uid == noteOwnerId;
    }

    // Comments on shared notes
    match /users/{noteOwnerId}/notes/{noteId}/comments/{commentId} {
      allow read: if request.auth != null
        && (request.auth.uid == noteOwnerId
            || get(/databases/$(database)/documents/users/$(noteOwnerId)/notes/$(noteId)).data.collaborators.hasAny([request.auth.uid]));
      allow create: if request.auth != null
        && (request.auth.uid == noteOwnerId
            || get(/databases/$(database)/documents/users/$(noteOwnerId)/notes/$(noteId)).data.collaborators.hasAny([request.auth.uid]));
      allow delete: if request.auth != null
        && request.auth.uid == resource.data.authorUid;
    }

    // Note versions
    match /users/{noteOwnerId}/notes/{noteId}/versions/{versionId} {
      allow read, write: if request.auth != null
        && request.auth.uid == noteOwnerId;
    }
  }
}
```

- [ ] **Step 2: Create storage.rules**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Audio attachments for notes
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

- [ ] **Step 3: Set up rules tests**

Create a `tests/` directory at project root (outside `test/` since these are JavaScript, not Dart). Create `tests/firestore.test.js`:

```javascript
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const testEnv = initializeTestEnvironment({
  projectId: 'mynotes-test',
  firestore: { rules: require('fs').readFileSync('firestore.rules', 'utf8') },
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

describe('Firestore rules', () => {
  it('denies unauthenticated read', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('users/user1/notes').get());
  });

  it('allows authenticated user to read own note', async () => {
    const db = testEnv.authenticatedContext('user1').firestore();
    await db.collection('users/user1/notes').doc('note1').set({ title: 'test' });
    await assertSucceeds(db.collection('users/user1/notes').doc('note1').get());
  });

  it('denies user A reading user B note', async () => {
    const dbA = testEnv.authenticatedContext('userA').firestore();
    const dbB = testEnv.authenticatedContext('userB').firestore();
    await dbB.collection('users/userB/notes').doc('secret').set({ title: 'secret' });
    await assertFails(dbA.collection('users/userB/notes').doc('secret').get());
  });

  it('allows collaborator to read shared note', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    const dbCollab = testEnv.authenticatedContext('collab').firestore();
    await dbOwner.collection('users/owner/notes').doc('shared').set({
      title: 'shared',
      collaborators: ['collab'],
    });
    await assertSucceeds(dbCollab.collection('users/owner/notes').doc('shared').get());
  });

  it('denies collaborator from writing to shared note', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    const dbCollab = testEnv.authenticatedContext('collab').firestore();
    await dbOwner.collection('users/owner/notes').doc('shared').set({
      title: 'shared',
      collaborators: ['collab'],
    });
    await assertFails(dbCollab.collection('users/owner/notes').doc('shared').set({ title: 'hacked' }));
  });
});
```

- [ ] **Step 4: Create package.json for test dependencies**

```json
{
  "name": "mynotes-rules-tests",
  "private": true,
  "scripts": {
    "test": "mocha tests/firestore.test.js --timeout 10000"
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^4.0.0",
    "mocha": "^10.0.0",
    "firebase-admin": "^13.0.0"
  }
}
```

- [ ] **Step 5: Run rules tests**

```bash
cd tests && npm install && npm test
```

- [ ] **Step 6: Run Dart analyze + test to verify no regression**

```
flutter analyze
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add firestore.rules storage.rules tests/ package.json
git commit -m "feat: add Firestore/Storage security rules with tests"
```

---

### Task 2: Add crypto dependencies and create encryption service

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/encryption/crypto_service.dart`
- Create: `test/core/encryption/crypto_service_test.dart`

- [ ] **Step 1: Add cryptography dependency**

```bash
flutter pub add cryptography
```

- [ ] **Step 2: Create crypto service**

`lib/core/encryption/crypto_service.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final AesGcm _aes = AesGcm.with256bits();
  static const int _saltLength = 32;
  static const int _ivLength = 12;

  /// Derive a 256-bit key from a password using PBKDF2.
  Future<SecretKey> deriveKey({
    required String password,
    required List<int> salt,
    int iterations = 100000,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Generate a random salt for PBKDF2.
  List<int> generateSalt() {
    final salt = Uint8List(_saltLength);
    // Use dart:math Random.secure() or cryptography's secure random
    final random = dart_math.Random.secure();
    for (var i = 0; i < _saltLength; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Encrypt plaintext with AES-256-GCM.
  Future<EncryptedPayload> encrypt({
    required SecretKey key,
    required String plaintext,
  }) async {
    final iv = Uint8List(_ivLength);
    final random = dart_math.Random.secure();
    for (var i = 0; i < _ivLength; i++) {
      iv[i] = random.nextInt(256);
    }

    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: iv,
    );

    return EncryptedPayload(
      ciphertext: secretBox.cipherText,
      nonce: secretBox.nonce,
      mac: secretBox.mac.bytes,
    );
  }

  /// Decrypt ciphertext with AES-256-GCM.
  Future<String> decrypt({
    required SecretKey key,
    required EncryptedPayload payload,
  }) async {
    final secretBox = SecretBox(
      payload.ciphertext,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );

    final plaintext = await _aes.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(plaintext);
  }
}

class EncryptedPayload {
  final List<int> ciphertext;
  final List<int> nonce;
  final List<int> mac;

  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  Map<String, dynamic> toMap() => {
    'ciphertext': base64Encode(ciphertext),
    'nonce': base64Encode(nonce),
    'mac': base64Encode(mac),
  };

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) => EncryptedPayload(
    ciphertext: base64Decode(map['ciphertext'] as String),
    nonce: base64Decode(map['nonce'] as String),
    mac: base64Decode(map['mac'] as String),
  );
}
```

Note: add `import 'dart:math' as dart_math;` at top.

- [ ] **Step 3: Write crypto service test**

`test/core/encryption/crypto_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';

void main() {
  late CryptoService crypto;

  setUp(() {
    crypto = CryptoService();
  });

  test('encrypt and decrypt round-trip', () async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKey(password: 'test-password', salt: salt);
    const original = 'Hello, encrypted world!';

    final encrypted = await crypto.encrypt(key: key, plaintext: original);
    final decrypted = await crypto.decrypt(key: key, payload: encrypted);

    expect(decrypted, equals(original));
  });

  test('wrong key fails decryption', () async {
    final salt = crypto.generateSalt();
    final key1 = await crypto.deriveKey(password: 'password1', salt: salt);
    final key2 = await crypto.deriveKey(password: 'password2', salt: salt);
    const original = 'Secret data';

    final encrypted = await crypto.encrypt(key: key1, plaintext: original);
    // Should throw when decrypting with wrong key
    try {
      await crypto.decrypt(key: key2, payload: encrypted);
      fail('Expected exception when decrypting with wrong key');
    } catch (_) {
      // Expected
    }
  });

  test('encrypted payload toMap/fromMap round-trip', () {
    final payload = EncryptedPayload(
      ciphertext: [1, 2, 3],
      nonce: [4, 5, 6],
      mac: [7, 8, 9],
    );

    final map = payload.toMap();
    final restored = EncryptedPayload.fromMap(map);

    expect(restored.ciphertext, equals(payload.ciphertext));
    expect(restored.nonce, equals(payload.nonce));
    expect(restored.mac, equals(payload.mac));
  });
}
```

- [ ] **Step 4: Create encryption directory + run tests**

```bash
mkdir -p lib/core/encryption
```

Write the files above, then:
```bash
flutter test test/core/encryption/crypto_service_test.dart
```

- [ ] **Step 5: Run full suite**

```bash
flutter analyze
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/encryption/ test/core/encryption/
git commit -m "feat: add AES-256-GCM encryption service with tests"
```

---

### Task 3: Implement key management (Master Key + wrapped Note Keys)

**Files:**
- Create: `lib/core/encryption/key_manager.dart`
- Create: `lib/core/encryption/providers/encryption_providers.dart`
- Create: `test/core/encryption/key_manager_test.dart`

- [ ] **Step 1: Create KeyManager**

`lib/core/encryption/key_manager.dart`:

```dart
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';

class KeyManager {
  final CryptoService _crypto = CryptoService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _masterKeyKey = 'master_key';
  static const _saltKey = 'key_salt';
  static const _keyVersion = 1;

  SecretKey? _cachedMasterKey;

  /// Derive and persist the Master Key on first login.
  Future<void> initializeMasterKey(String password) async {
    final salt = _crypto.generateSalt();
    final masterKey = await _crypto.deriveKey(
      password: password,
      salt: salt,
    );

    // Store salt and a key-wrapped version for later re-derivation
    final masterKeyBytes = await masterKey.extractBytes();
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    // Store the key material (wrapped with itself for persistence)
    // Alternative: store salt only and re-derive on each login
    await _storage.write(
      key: _masterKeyKey,
      value: base64Encode(masterKeyBytes),
    );

    _cachedMasterKey = masterKey;
  }

  /// Load Master Key from secure storage (called on app start / login).
  Future<SecretKey?> loadMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey;

    final keyBytes = await _storage.read(key: _masterKeyKey);
    if (keyBytes == null) return null;

    _cachedMasterKey = SecretKey(base64Decode(keyBytes));
    return _cachedMasterKey;
  }

  /// Generate a new random Note Key and wrap it with the Master Key.
  Future<Map<String, String>> createNoteKey(String noteId) async {
    final masterKey = await loadMasterKey();
    if (masterKey == null) throw Exception('Master Key not initialized');

    // Generate random Note Key
    final noteKey = SecretKey(Uint8List.fromList(
      List.generate(32, (_) => dart_math.Random.secure().nextInt(256)),
    ));

    // Wrap Note Key with Master Key
    final noteKeyBytes = await noteKey.extractBytes();
    final encrypted = await _crypto.encrypt(
      key: masterKey,
      plaintext: base64Encode(noteKeyBytes),
    );

    return {
      '$_keyVersion': base64Encode(encrypted.ciphertext + encrypted.nonce + encrypted.mac),
    };
  }

  /// Unwrap a Note Key using the Master Key.
  Future<SecretKey> unwrapNoteKey(Map<String, String> wrappedKeyData) async {
    final masterKey = await loadMasterKey();
    if (masterKey == null) throw Exception('Master Key not initialized');

    // Find latest version
    final wrappedKeyStr = wrappedKeyData['$_keyVersion'];
    if (wrappedKeyStr == null) throw Exception('No key version $_keyVersion');

    final combined = base64Decode(wrappedKeyStr);
    final payload = EncryptedPayload(
      ciphertext: combined.sublist(0, combined.length - 24),
      nonce: combined.sublist(combined.length - 24, combined.length - 12),
      mac: combined.sublist(combined.length - 12),
    );

    final noteKeyStr = await _crypto.decrypt(key: masterKey, payload: payload);
    return SecretKey(base64Decode(noteKeyStr));
  }

  /// Clear Master Key from memory (on app background).
  void clearCachedKey() {
    _cachedMasterKey = null;
  }

  /// Check if a Master Key exists (user has set up encryption).
  Future<bool> hasMasterKey() async {
    return await _storage.read(key: _masterKeyKey) != null;
  }
}
```

- [ ] **Step 2: Create encryption providers**

`lib/core/encryption/providers/encryption_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager();
});

final hasMasterKeyProvider = FutureProvider<bool>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  return keyManager.hasMasterKey();
});
```

- [ ] **Step 3: Write key manager test**

`test/core/encryption/key_manager_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/key_manager.dart';

void main() {
  late KeyManager keyManager;

  setUp(() {
    keyManager = KeyManager();
  });

  test('derives 256-bit key from password', () async {
    final salt = CryptoService().generateSalt();
    final key = await CryptoService().deriveKey(password: 'test-password', salt: salt);
    final extracted = await key.extractBytes();
    expect(extracted.length, equals(32));
  });

  test('same password with different salt produces different keys', () async {
    final crypto = CryptoService();
    final salt1 = crypto.generateSalt();
    final salt2 = crypto.generateSalt();
    final key1 = await crypto.deriveKey(password: 'password', salt: salt1);
    final key2 = await crypto.deriveKey(password: 'password', salt: salt2);
    final bytes1 = await key1.extractBytes();
    final bytes2 = await key2.extractBytes();
    expect(bytes1, isNot(equals(bytes2)));
  });

  test('different password with same salt produces different keys', () async {
    final crypto = CryptoService();
    final salt = crypto.generateSalt();
    final key1 = await crypto.deriveKey(password: 'password-a', salt: salt);
    final key2 = await crypto.deriveKey(password: 'password-b', salt: salt);
    final bytes1 = await key1.extractBytes();
    final bytes2 = await key2.extractBytes();
    expect(bytes1, isNot(equals(bytes2)));
  });
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/core/encryption/
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/encryption/providers/ lib/core/encryption/key_manager.dart test/core/encryption/key_manager_test.dart
git commit -m "feat: add key management with wrapped Note Keys"
```

---

### Task 4: Integrate encryption into Note model and NotesService

**Files:**
- Modify: `lib/features/notes/data/note.dart` — add encrypted fields + encrypt/decrypt methods
- Modify: `lib/features/notes/data/notes_service.dart` — encrypt on save, decrypt on read
- Modify: `lib/features/notes/presentation/note_editor_view.dart` — decrypt before editing
- Modify: `lib/features/notes/presentation/notes_home_view.dart` — decrypt titles for list

- [ ] **Step 1: Add encrypted fields to Note model**

In `lib/features/notes/data/note.dart`, modify the existing class:

```dart
class Note {
  final String id;
  final String? encryptedTitle;   // base64 ciphertext when encrypted
  final String? encryptedContent; // base64 ciphertext when encrypted
  final String? wrappedKey;       // base64 wrapped Note Key (latest version)
  final int encryptionVersion;    // 0 = plaintext, 1 = AES-256-GCM
  final int colorIndex;
  final bool isPinned;
  final bool isLocked;
  final String? pinHash;
  final String? pinSalt;
  final bool localOnly;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ... keep existing fields but make title/content nullable
```

Update `fromFirestore` and `toMap` to handle encrypted fields. When `encryptionVersion == 0`, use plaintext `title`/`content` fields (backward compat). When `encryptionVersion >= 1`, the actual content is in `encryptedTitle`/`encryptedContent`.

- [ ] **Step 2: Create encrypt/decrypt methods on Note**

```dart
Future<Note> encryptNote(SecretKey noteKey, CryptoService crypto) async {
  final titleEnc = await crypto.encrypt(key: noteKey, plaintext: title);
  final contentEnc = await crypto.encrypt(key: noteKey, plaintext: content);
  return copyWith(
    encryptedTitle: base64Encode(titleEnc.ciphertext + titleEnc.nonce + titleEnc.mac),
    encryptedContent: base64Encode(contentEnc.ciphertext + contentEnc.nonce + contentEnc.mac),
    encryptionVersion: 1,
  );
}

Future<Note> decryptNote(SecretKey noteKey, CryptoService crypto) async {
  // Parse encryptedTitle, encryptedContent back to EncryptedPayload
  // Decrypt and return Note with plaintext title/content
}
```

- [ ] **Step 3: Update NotesService to encrypt/decrypt**

Modify `createNote` to:
1. Generate a Note Key via `KeyManager.createNoteKey(noteId)`
2. Encrypt the note content with `crypto.encrypt(key: noteKey, plaintext: content)`
3. Store `encryptedContent`, `encryptedTitle`, `wrappedKey`, `encryptionVersion: 1` in Firestore

Modify `watchNotes` to:
1. After fetching from Firestore, check if `encryptionVersion >= 1`
2. If encrypted, decrypt the title only (for list previews) — batch decrypt for performance
3. Return decrypted Note objects

Modify `updateNote` to:
1. Encrypt content before saving
2. Reuse existing Note Key (from `wrappedKey` field)

- [ ] **Step 4: Update NoteEditorView**

Read existing code — before displaying a note, ensure it's decrypted (call `note.decryptNote()`). When saving, encrypt before calling `notesService.updateNote()`.

- [ ] **Step 5: Update NotesHomeView**

The stream from `watchNotes` now returns decrypted Notes. No change needed to the display logic if the service handles decryption.

- [ ] **Step 6: Run full test suite**

```bash
flutter analyze
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/data/note.dart lib/features/notes/data/notes_service.dart lib/features/notes/presentation/
git commit -m "feat: integrate E2EE into note save/load flow"
```

---

### Task 5: Client-side full-text search

**Files:**
- Modify: `lib/core/db/tables.dart` — add FTS5 virtual table
- Modify: `lib/core/db/app_database.dart` — add search DAO
- Create: `lib/features/notes/data/local_note_repository.dart`
- Create: `lib/features/notes/providers/search_provider.dart`
- Create: `test/features/notes/search/search_test.dart`

- [ ] **Step 1: Add FTS5 table to drift**

In `lib/core/db/tables.dart`, add:

```dart
class NoteFts extends Table {
  TextColumn get noteId => text()();
  TextColumn get ownerId => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {noteId};

  @override
  String get createTable => '''
    CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
      note_id UNINDEXED,
      owner_id UNINDEXED,
      title,
      content,
      tokenize='porter unicode61'
    )
  ''';
}
```

- [ ] **Step 2: Add search methods to AppDatabase**

In `lib/core/db/app_database.dart`, add:

```dart
Future<void> indexNote({required String noteId, required String ownerId, required String title, required String content}) async {
  await customInsert('note_fts', {
    'note_id': noteId,
    'owner_id': ownerId,
    'title': title,
    'content': content,
  }, mode: InsertMode.replace);
}

Future<void> removeNoteIndex(String noteId) async {
  await customUpdate(
    'DELETE FROM note_fts WHERE note_id = ?',
    [noteId],
  );
}

Future<List<String>> searchNotes(String ownerId, String query) async {
  final result = await customSelect(
    'SELECT note_id FROM note_fts WHERE owner_id = ? AND note_fts MATCH ?',
    [ownerId, query],
  );
  return result.map((row) => row.data['note_id'] as String).toList();
}
```

- [ ] **Step 3: Create local note repository**

`lib/features/notes/data/local_note_repository.dart`:

```dart
import 'package:mynotes/core/db/app_database.dart' as db;
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';

class LocalNoteRepository {
  final db.AppDatabase _database;
  final NotesService _notesService;

  LocalNoteRepository(this._database, this._notesService);

  /// Build FTS index from all decrypted notes for a user.
  Future<void> rebuildIndex(String uid) async {
    // Fetch all notes from Firestore, decrypt, index
  }

  Future<List<String>> search(String uid, String query) async {
    return _database.searchNotes(uid, query);
  }
}
```

- [ ] **Step 4: Create search provider**

`lib/features/notes/providers/search_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/db/app_database.dart';
import 'package:mynotes/core/providers/providers.dart';

final searchResultsProvider = FutureProvider.family<List<String>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final db = ref.watch(databaseProvider);
  // Use a hardcoded owner ID for now — will come from auth state
  return db.searchNotes('current-user', query);
});
```

- [ ] **Step 5: Write search test**

`test/features/notes/search/search_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/db/app_database.dart';
import 'package:mynotes/core/db/tables.dart';

void main() {
  test('index and search note by title', () async {
    final db = AppDatabase();
    await db.indexNote(
      noteId: 'note-1',
      ownerId: 'user-1',
      title: 'Shopping List',
      content: 'Milk, eggs, bread',
    );
    await db.indexNote(
      noteId: 'note-2',
      ownerId: 'user-1',
      title: 'Work Notes',
      content: 'Meeting at 3pm',
    );

    final results = await db.searchNotes('user-1', 'shopping');

    expect(results, contains('note-1'));
    expect(results, isNot(contains('note-2')));
    await db.close();
  });

  test('search scoped to owner', () async {
    final db = AppDatabase();
    await db.indexNote(
      noteId: 'note-1',
      ownerId: 'user-1',
      title: 'Shared Note',
      content: 'Hello',
    );
    await db.indexNote(
      noteId: 'note-2',
      ownerId: 'user-2',
      title: 'Shared Note',
      content: 'Hello',
    );

    final user1Results = await db.searchNotes('user-1', 'shared');
    final user2Results = await db.searchNotes('user-2', 'shared');

    expect(user1Results, contains('note-1'));
    expect(user2Results, contains('note-2'));
    expect(user2Results, isNot(contains('note-1')));
    await db.close();
  });

  test('removing index removes from search results', () async {
    final db = AppDatabase();
    await db.indexNote(noteId: 'note-1', ownerId: 'user-1', title: 'Temporary', content: 'Will be deleted');
    await db.removeNoteIndex('note-1');

    final results = await db.searchNotes('user-1', 'temporary');

    expect(results, isEmpty);
    await db.close();
  });
}
```

- [ ] **Step 6: Run tests**

```bash
flutter analyze
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/core/db/tables.dart lib/core/db/app_database.dart lib/features/notes/data/local_note_repository.dart lib/features/notes/providers/search_provider.dart test/features/notes/search/
git commit -m "feat: add client-side FTS5 search"
```

---

### Task 6: Per-note biometric/PIN lock

**Files:**
- Modify: `pubspec.yaml` — add `local_auth`
- Create: `lib/features/lock/services/lock_service.dart`
- Create: `lib/features/lock/providers/lock_providers.dart`
- Create: `lib/features/lock/presentation/lock_screen.dart`
- Modify: `lib/features/notes/presentation/notes_home_view.dart` — add lock icon, unlock trigger
- Modify: `lib/features/notes/presentation/note_editor_view.dart` — add lock/pin toggle UI
- Create: `test/features/lock/lock_service_test.dart`

- [ ] **Step 1: Add local_auth dependency**

```bash
flutter pub add local_auth
```

- [ ] **Step 2: Create LockService**

`lib/features/lock/services/lock_service.dart`:

```dart
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:math';
import 'dart:convert';

class LockService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const int _pinIterations = 10000;

  /// Check if biometric authentication is available.
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate using biometrics.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock this note',
      );
    } catch (_) {
      return false;
    }
  }

  /// Hash a PIN with PBKDF2 + random salt.
  Future<PinHash> hashPin(String pin) async {
    final salt = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pinIterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final keyBytes = await key.extractBytes();
    return PinHash(
      hash: base64Encode(keyBytes),
      salt: base64Encode(salt),
    );
  }

  /// Verify a PIN against stored hash.
  Future<bool> verifyPin(String pin, PinHash stored) async {
    final salt = base64Decode(stored.salt);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pinIterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final keyBytes = await key.extractBytes();
    final computedHash = base64Encode(keyBytes);
    return computedHash == stored.hash;
  }
}

class PinHash {
  final String hash;
  final String salt;
  const PinHash({required this.hash, required this.salt});
}
```

- [ ] **Step 3: Create lock providers**

`lib/features/lock/providers/lock_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/lock/services/lock_service.dart';

final lockServiceProvider = Provider<LockService>((ref) {
  return LockService();
});

final unlockedNotesProvider = StateProvider<Set<String>>((ref) {
  return {};
});
```

- [ ] **Step 4: Create lock screen UI**

`lib/features/lock/presentation/lock_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/lock/providers/lock_providers.dart';

class LockScreen extends ConsumerStatefulWidget {
  final String noteId;
  final String? pinHash;
  final String? pinSalt;
  final Widget child; // The locked content to show after auth

  const LockScreen({
    super.key,
    required this.noteId,
    this.pinHash,
    this.pinSalt,
    required this.child,
  });

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _isLocked = true;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;

  @override
  Widget build(BuildContext context) {
    final unlockedNotes = ref.watch(unlockedNotesProvider);

    if (!_isLocked || unlockedNotes.contains(widget.noteId)) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Locked Note')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 24),
            const Text('This note is locked'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _canAttempt() ? _authenticate : null,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock with biometrics'),
            ),
            if (widget.pinHash != null) ...[
              const SizedBox(height: 16),
              // PIN input field
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Enter PIN',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _verifyPin,
              ),
            ],
            if (_cooldownUntil != null)
              Text('Too many attempts. Try again later.'),
          ],
        ),
      ),
    );
  }

  bool _canAttempt() {
    if (_cooldownUntil == null) return true;
    if (DateTime.now().isAfter(_cooldownUntil!)) {
      _cooldownUntil = null;
      _failedAttempts = 0;
      return true;
    }
    return false;
  }

  Future<void> _authenticate() async {
    final lockService = ref.read(lockServiceProvider);
    final success = await lockService.authenticateWithBiometrics();
    if (success) {
      setState(() => _isLocked = false);
      ref.read(unlockedNotesProvider.notifier).update((set) => {...set, widget.noteId});
    }
  }

  Future<void> _verifyPin(String pin) async {
    if (widget.pinHash == null || widget.pinSalt == null) return;
    final lockService = ref.read(lockServiceProvider);
    final valid = await lockService.verifyPin(
      pin,
      PinHash(hash: widget.pinHash!, salt: widget.pinSalt!),
    );
    if (valid) {
      setState(() => _isLocked = false);
      ref.read(unlockedNotesProvider.notifier).update((set) => {...set, widget.noteId});
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        setState(() => _cooldownUntil = DateTime.now().add(const Duration(seconds: 30)));
      }
    }
  }
}
```

- [ ] **Step 5: Integrate lock into NotesHomeView**

In the note card in `notes_home_view.dart`, when a note has `isLocked: true`, show a padlock icon. When tapping a locked note, navigate to:

```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (context) => LockScreen(
    noteId: note.id,
    pinHash: note.pinHash,
    pinSalt: note.pinSalt,
    child: NoteEditorView(authUser: widget.authUser, note: note),
  ),
));
```

When `isLocked: false`, navigate directly to `NoteEditorView` as before.

- [ ] **Step 6: Add lock toggle to NoteEditorView**

Add a lock button in the note editor toolbar. On tap:
- If biometrics available: enable biometric lock
- If not: prompt to set a PIN
- Sets `isLocked: true`, stores `pinHash`/`pinSalt` if PIN

```dart
IconButton(
  icon: Icon(note.isLocked ? Icons.lock : Icons.lock_open),
  onPressed: _toggleLock,
)
```

- [ ] **Step 7: Write lock service test**

`test/features/lock/lock_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/lock/services/lock_service.dart';

void main() {
  late LockService lockService;

  setUp(() {
    lockService = LockService();
  });

  test('hashPin produces consistent results', () async {
    const pin = '123456';
    final hash1 = await lockService.hashPin(pin);
    final hash2 = await lockService.hashPin(pin);

    // Same pin should produce different hashes (different salt each time)
    expect(hash1.hash, isNot(equals(hash2.hash)));
  });

  test('verifyPin succeeds with correct pin', () async {
    const pin = '654321';
    final stored = await lockService.hashPin(pin);
    final valid = await lockService.verifyPin(pin, stored);
    expect(valid, isTrue);
  });

  test('verifyPin fails with wrong pin', () async {
    const correct = '123456';
    const wrong = '654321';
    final stored = await lockService.hashPin(correct);
    final valid = await lockService.verifyPin(wrong, stored);
    expect(valid, isFalse);
  });
}
```

- [ ] **Step 8: Run full test suite**

```bash
flutter analyze
flutter test
```

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/lock/ test/features/lock/
git add lib/features/notes/presentation/notes_home_view.dart lib/features/notes/presentation/note_editor_view.dart
git commit -m "feat: add per-note biometric/PIN lock"
```
