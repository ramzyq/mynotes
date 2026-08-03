# Shareable Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a note owner share a note with anyone via an unguessable link, with a per-link open/approval mode, using E2EE X25519 key wrapping.

**Architecture:** Owner creates a `shareLinks/{token}` doc. The recipient opens `https://{domain}/join/{token}`, must be logged in (web fallback tells them to install + create an account), and their device writes a `shareLinks/{token}/requests/{recipientUid}` doc (`pending` for approval mode, `approved` for open mode). The owner's device watches its own requests and, once approved, wraps the note key with the recipient's X25519 public key and adds them to `notes/{noteId}.collaborators`. The recipient's shared-notes feed then decrypts the note via ECDH with the owner's public key. The broken per-user `sha256(masterKey‖uid)` sharing key is replaced with deterministic X25519 keypairs derived from the master key.

**Tech Stack:** Dart 3.11 / Flutter 3.41, Riverpod 2.6, Cloud Firestore, `cryptography` 2.9 (X25519 + AES-GCM), `app_links`, `share_plus`, `shared_preferences`, Firestore Security Rules.

## Global Constraints

- E2EE: note titles/content are stored encrypted in Firestore. Only the plaintext note **title** is stored on `shareLinks/{token}.noteTitlePlain` (design decision; the token is unguessable).
- Link never carries a key. Recipients must be logged in before their request doc is written.
- Default link mode is `approval`. `open` mode auto-approves (recipient writes `status: 'approved'`; owner's device completes on next sync).
- Wrapped note keys live in the note doc field `encryptedKeys: Map<String, String>` keyed by recipient UID (existing convention in `shareNote`).
- Public keys are base64 strings on `users/{uid}.publicKey`, written by `ensureUserProfile`.
- Do not change `notesService.getSharedNotes` collectionGroup query semantics; only its decrypt path.
- Keep every task green: `flutter analyze` must be clean and the full `flutter test` suite must pass at the end of every task.
- Commits happen only when the user has confirmed; each task ends with a commit step.
- External human inputs (not guessable, do not invent values): the share domain, Apple Team ID, Android release-keystore SHA-256 fingerprint, App Store/Play store URLs. Tasks 10 and 11 are gated on these.

---

### Task 1: X25519 deterministic keypairs + ECDH key wrap/unwrap

Fix the broken sharing crypto. Today `KeyManager.deriveSharingKey` derives `sha256(masterKey ‖ uid)`, which never matches between owner and recipient. Replace with deterministic X25519 keypairs derived from each user's master key, and ECDH-based wrap/unwrap. The `cryptography` 2.9.0 package API: `X25519().newKeyPairFromSeed(seed)` (32-byte seed), `SimplePublicKey(bytes, type: KeyPairType.x25519)`, `X25519().sharedSecretKey(keyPair:, remotePublicKey:)`.

**Files:**
- Create: `lib/core/encryption/sharing_keys.dart`
- Modify: `lib/core/encryption/key_manager.dart`
- Modify: `lib/features/collaboration/services/share_service.dart` (call site only)
- Modify: `lib/features/notes/data/notes_service.dart` (call site only)
- Test: `test/core/encryption/sharing_keys_test.dart`, `test/core/encryption/key_manager_test.dart`

**Interfaces:**
- Produces (used by Tasks 2-4, 7-9):
  - `SharingKeys.keyPairFromMasterKey(List<int> masterKeyBytes) → Future<SimpleKeyPair>`
  - `SharingKeys.publicKeyOf(SimpleKeyPair pair) → Future<List<int>>`
  - `SharingKeys.sharedSecret({required SimpleKeyPair myKeyPair, required List<int> remotePublicKey}) → Future<SecretKey>`
  - `KeyManager.getMyPublicKey() → Future<Uint8List>` (base64-encoded by callers)
  - `KeyManager.wrapNoteKeyForCollaborator({required SecretKey noteKey, required List<int> recipientPublicKey}) → Future<String>`
  - `KeyManager.unwrapCollaboratorNoteKey({required String encryptedKeyStr, required List<int> ownerPublicKey}) → Future<SecretKey>`
- Consumes: existing `KeyManager.ensureMasterKey()`, `KeyManager._splitPayload`, `CryptoService.encrypt/decrypt`, top-level `_sha256` in key_manager.dart.

- [ ] **Step 1: Write the failing ECDH two-party test**

`test/core/encryption/sharing_keys_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/sharing_keys.dart';

void main() {
  final sharing = SharingKeys();

  test('ECDH shared secrets match between two independent keypairs', () async {
    final ownerMaster = List<int>.generate(32, (i) => i);
    final recipientMaster = List<int>.generate(32, (i) => 255 - i);
    final ownerPair = await sharing.keyPairFromMasterKey(ownerMaster);
    final recipientPair = await sharing.keyPairFromMasterKey(recipientMaster);
    final ownerPub = await sharing.publicKeyOf(ownerPair);
    final recipientPub = await sharing.publicKeyOf(recipientPair);

    final s1 = await sharing.sharedSecret(myKeyPair: ownerPair, remotePublicKey: recipientPub);
    final s2 = await sharing.sharedSecret(myKeyPair: recipientPair, remotePublicKey: ownerPub);

    expect(await s1.extractBytes(), equals(await s2.extractBytes()));
  });

  test('same master key produces same public key', () async {
    final master = List<int>.generate(32, (i) => 42 + i);
    final pairA = await sharing.keyPairFromMasterKey(master);
    final pairB = await sharing.keyPairFromMasterKey(master);
    expect(await sharing.publicKeyOf(pairA), equals(await sharing.publicKeyOf(pairB)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/encryption/sharing_keys_test.dart`
Expected: FAIL with "Error: Type 'SharingKeys' not found."

- [ ] **Step 3: Implement SharingKeys**

`lib/core/encryption/sharing_keys.dart`:

```dart
import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class SharingKeys {
  static const String _seedDomain = 'mynotes-x25519-v1';
  final X25519 _x25519 = X25519();
  final Sha256 _sha256 = Sha256();

  Future<SimpleKeyPair> keyPairFromMasterKey(List<int> masterKeyBytes) async {
    final seedInput = [...utf8.encode(_seedDomain), ...masterKeyBytes];
    final seed = await _sha256.hash(seedInput);
    return _x25519.newKeyPairFromSeed(seed.bytes);
  }

  Future<List<int>> publicKeyOf(SimpleKeyPair pair) async {
    final publicKey = await pair.extractPublicKey();
    return publicKey.extract();
  }

  Future<SecretKey> sharedSecret({
    required SimpleKeyPair myKeyPair,
    required List<int> remotePublicKey,
  }) {
    return _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: SimplePublicKey(
        remotePublicKey,
        type: KeyPairType.x25519,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/encryption/sharing_keys_test.dart`
Expected: PASS

- [ ] **Step 5: Write failing KeyManager tests**

Append to `test/core/encryption/key_manager_test.dart`:

```dart
test('getMyPublicKey is deterministic for the same master key', () async {
  FlutterSecureStorage.setMockInitialValues({});
  final keyManager = KeyManager();
  final first = await keyManager.getMyPublicKey();
  final second = await keyManager.getMyPublicKey();
  expect(second, equals(first));
});

test('wrap and unwrap with own public key round-trips the note key', () async {
  FlutterSecureStorage.setMockInitialValues({});
  final keyManager = KeyManager();
  final wrapped = await keyManager.createNoteKey('note-1');
  final noteKey = await keyManager.unwrapNoteKey(wrapped);

  final ownPublicKey = await keyManager.getMyPublicKey();
  final encryptedKey = await keyManager.wrapNoteKeyForCollaborator(
    noteKey: noteKey,
    recipientPublicKey: ownPublicKey,
  );
  final recovered = await keyManager.unwrapCollaboratorNoteKey(
    encryptedKeyStr: encryptedKey,
    ownerPublicKey: ownPublicKey,
  );

  final original = await noteKey.extractBytes();
  final result = await recovered.extractBytes();
  expect(result, equals(original));
});

test('unwrapping with a different user public key fails', () async {
  FlutterSecureStorage.setMockInitialValues({});
  final owner = KeyManager();
  final wrapped = await owner.createNoteKey('note-1');
  final noteKey = await owner.unwrapNoteKey(wrapped);

  FlutterSecureStorage.setMockInitialValues({});
  final stranger = KeyManager();
  final strangerPublicKey = await stranger.getMyPublicKey();
  final ownerPublicKey = await owner.getMyPublicKey();

  final encryptedKey = await owner.wrapNoteKeyForCollaborator(
    noteKey: noteKey,
    recipientPublicKey: strangerPublicKey,
  );

  expect(
    () => stranger.unwrapCollaboratorNoteKey(
      encryptedKeyStr: encryptedKey,
      ownerPublicKey: ownerPublicKey,
    ),
    throwsA(isA<Exception>()),
  );
});
```

Note: `unwrapCollaboratorNoteKey` will throw when the AES-GCM auth tag does not verify. If the implementation instead returns a wrong key silently, this test must be adjusted to assert the decrypted bytes differ — do not weaken it.

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/core/encryption/key_manager_test.dart`
Expected: FAIL — `getMyPublicKey` does not exist.

- [ ] **Step 7: Rewrite KeyManager sharing methods**

In `lib/core/encryption/key_manager.dart`:
- Add a field: `final SharingKeys _sharing = SharingKeys();`
- Delete `deriveSharingKey` (lines 151-158).
- Replace `wrapNoteKeyForCollaborator` and `unwrapCollaboratorNoteKey`:

```dart
  /// Encrypt a note key so only the owner of [recipientPublicKey] can unwrap it.
  Future<String> wrapNoteKeyForCollaborator({
    required SecretKey noteKey,
    required List<int> recipientPublicKey,
  }) async {
    final sharedSecret = await _ecdhSharedSecret(recipientPublicKey);
    final noteKeyBytes = await noteKey.extractBytes();
    final encrypted = await _crypto.encrypt(
      key: sharedSecret,
      plaintext: base64Encode(noteKeyBytes),
    );
    final combined = encrypted.ciphertext + encrypted.nonce + encrypted.mac;
    return base64Encode(combined);
  }

  /// Decrypt a note key that was wrapped for us by the owner of [ownerPublicKey].
  Future<SecretKey> unwrapCollaboratorNoteKey({
    required String encryptedKeyStr,
    required List<int> ownerPublicKey,
  }) async {
    final sharedSecret = await _ecdhSharedSecret(ownerPublicKey);
    final combined = base64Decode(encryptedKeyStr);
    final payload = _splitPayload(combined);
    final noteKeyStr = await _crypto.decrypt(key: sharedSecret, payload: payload);
    return SecretKey(base64Decode(noteKeyStr));
  }

  /// Deterministic X25519 keypair derived from this device's master key.
  Future<SimpleKeyPair> _loadMyKeyPair() async {
    final masterKey = await ensureMasterKey();
    final masterBytes = await masterKey.extractBytes();
    return _sharing.keyPairFromMasterKey(masterBytes);
  }

  Future<SecretKey> _ecdhSharedSecret(List<int> remotePublicKey) async {
    return _sharing.sharedSecret(
      myKeyPair: await _loadMyKeyPair(),
      remotePublicKey: remotePublicKey,
    );
  }

  /// This user's X25519 public key (32 bytes), derived deterministically
  /// from the master key.
  Future<Uint8List> getMyPublicKey() async {
    final keyPair = await _loadMyKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.extract());
  }
```

Add the import: `import 'package:mynotes/core/encryption/sharing_keys.dart';`

- [ ] **Step 8: Update the email-share call site in share_service.dart**

In `lib/features/collaboration/services/share_service.dart`, add `import 'dart:convert';` and change the `shareNote` wrap block (lines 70-85) to fetch the recipient's public key:

```dart
    final recipientDoc = await firestore
        .collection('users')
        .doc(collaboratorUid)
        .get();
    final recipientPublicKeyB64 = recipientDoc.data()?['publicKey'] as String?;
    if (recipientPublicKeyB64 == null) {
      throw Exception('Recipient has not set up sharing yet; ask them to open the app once.');
    }

    if (storedEncryptionVersion >= 1 && storedWrappedKey != null) {
      final noteKey = await keyManager
          .unwrapNoteKey((storedWrappedKey as Map).cast<String, String>());
      final encryptedKey = await keyManager.wrapNoteKeyForCollaborator(
        noteKey: noteKey,
        recipientPublicKey: base64Decode(recipientPublicKeyB64),
      );
      currentEncryptedKeys[collaboratorUid] = encryptedKey;
    }
```

- [ ] **Step 9: Update the shared-notes decrypt call site in notes_service.dart**

In `lib/features/notes/data/notes_service.dart`, add `import 'dart:convert';` and replace the body of `_decryptSharedNote` (lines 422-438):

```dart
  Future<Note> _decryptSharedNote(String uid, Note note, String ownerUid) async {
    if (note.encryptionVersion >= 1 && note.encryptedKeys != null) {
      final encryptedKeyStr = note.encryptedKeys![uid];
      if (encryptedKeyStr != null) {
        try {
          final ownerDoc = await firestore
              .collection('users')
              .doc(ownerUid)
              .get();
          final ownerPublicKeyB64 = ownerDoc.data()?['publicKey'] as String?;
          if (ownerPublicKeyB64 == null) return note;
          final noteKey = await keyManager.unwrapCollaboratorNoteKey(
            encryptedKeyStr: encryptedKeyStr,
            ownerPublicKey: base64Decode(ownerPublicKeyB64),
          );
          return note.decryptNote(noteKey, crypto);
        } catch (_) {
          return note;
        }
      }
    }
    return note;
  }
```

- [ ] **Step 10: Run the full suite**

Run: `flutter analyze` then `flutter test`
Expected: analyze clean; all tests pass (existing 68 + new ones).

- [ ] **Step 11: Commit**

```bash
git add lib/core/encryption/sharing_keys.dart lib/core/encryption/key_manager.dart lib/features/collaboration/services/share_service.dart lib/features/notes/data/notes_service.dart test/core/encryption/sharing_keys_test.dart test/core/encryption/key_manager_test.dart
git commit -m "fix(encryption): use X25519 ECDH for collaborator key wrapping"
```

---

### Task 2: Publish the sharing public key on the user profile

**Files:**
- Modify: `lib/features/collaboration/services/share_service.dart`
- Test: (manual) — covered by rules test in Task 5; verify via analyze + run.

**Interfaces:**
- Consumes: `KeyManager.getMyPublicKey()` from Task 1.
- Produces: `users/{uid}.publicKey` (base64 string) written by `ensureUserProfile`; consumed by Task 1's `shareNote`, Task 3's `joinSharedNote`, Task 4's `completeShareForRequest`, and `notes_service._decryptSharedNote`.

- [ ] **Step 1: Update ensureUserProfile**

Replace `ensureUserProfile` (lines 20-29) in `share_service.dart`:

```dart
  Future<void> ensureUserProfile({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    final publicKey = await keyManager.getMyPublicKey();
    await firestore.collection('users').doc(uid).set({
      'email': email.toLowerCase(),
      'displayName': displayName ?? '',
      'publicKey': base64Encode(publicKey),
    }, SetOptions(merge: true));
  }
```

`ensureUserProfile` already runs on every app open via `notes_home_view.dart:40-48`, so existing users get `publicKey` on next launch. No migration needed.

- [ ] **Step 2: Verify**

Run: `flutter analyze` and `flutter test`
Expected: clean; all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/collaboration/services/share_service.dart
git commit -m "feat(share): publish X25519 public key on user profile"
```

---

### Task 3: Share-link and join-request data API

**Files:**
- Create: `lib/features/collaboration/models/share_link.dart`
- Create: `lib/features/collaboration/models/join_request.dart`
- Modify: `lib/features/collaboration/services/share_service.dart`
- Test: `test/features/collaboration/share_service_test.dart` (pure logic)

**Interfaces:**
- Consumes: `ShareLinkToken`, `buildJoinUrl` (defined below), `KeyManager.getMyPublicKey`, Firestore.
- Produces (used by Tasks 4, 6, 7, 9):
  - `enum JoinStatus { notFound, ownerLink, alreadyShared, pending, approved, shared }`
  - `class JoinResult { final JoinStatus status; final String? noteTitle; const JoinResult(this.status, {this.noteTitle}); }`
  - `class ShareLink { final String token; final String url; final String mode; final String noteTitle; const ShareLink({...}); }`
  - `({JoinStatus status, String requestStatus}) planJoin({required bool linkExists, required bool isOwner, required bool alreadyShared, required bool requestExists, required String existingRequestStatus, required String linkMode})`
  - `ShareService.createShareLink({required String uid, required Note note, required String mode}) → Future<ShareLink>`
  - `ShareService.revokeShareLink({required String token}) → Future<void>`
  - `ShareService.joinSharedNote({required String uid, required String token, required List<int> recipientPublicKey, required String recipientName, required String recipientEmail}) → Future<JoinResult>`

- [ ] **Step 1: Write failing tests for pure helpers**

`test/features/collaboration/share_service_test.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/config/app_config.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';

void main() {
  group('ShareLinkToken', () {
    test('generates 22-char base62 tokens', () {
      final token = ShareLinkToken.generate(random: math.Random(42));
      expect(token.length, 22);
      expect(RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(token), isTrue);
    });

    test('different seeds produce different tokens', () {
      final a = ShareLinkToken.generate(random: math.Random(1));
      final b = ShareLinkToken.generate(random: math.Random(2));
      expect(a, isNot(equals(b)));
    });
  });

  group('buildJoinUrl', () {
    test('produces https join url on the share domain', () {
      expect(buildJoinUrl('abc123'), 'https://$appConfig.shareDomain/join/abc123');
    });
  });

  group('planJoin', () {
    test('open mode auto-approves when no request exists', () {
      final plan = planJoin(
        linkExists: true, isOwner: false, alreadyShared: false,
        requestExists: false, existingRequestStatus: '', linkMode: 'open',
      );
      expect(plan.status, JoinStatus.approved);
      expect(plan.requestStatus, 'approved');
    });

    test('approval mode creates a pending request', () {
      final plan = planJoin(
        linkExists: true, isOwner: false, alreadyShared: false,
        requestExists: false, existingRequestStatus: '', linkMode: 'approval',
      );
      expect(plan.status, JoinStatus.pending);
      expect(plan.requestStatus, 'pending');
    });

    test('missing link maps to notFound', () {
      final plan = planJoin(
        linkExists: false, isOwner: false, alreadyShared: false,
        requestExists: false, existingRequestStatus: '', linkMode: 'approval',
      );
      expect(plan.status, JoinStatus.notFound);
    });

    test('owner opening own link is flagged', () {
      final plan = planJoin(
        linkExists: true, isOwner: true, alreadyShared: false,
        requestExists: false, existingRequestStatus: '', linkMode: 'open',
      );
      expect(plan.status, JoinStatus.ownerLink);
    });

    test('existing shared request returns shared', () {
      final plan = planJoin(
        linkExists: true, isOwner: false, alreadyShared: false,
        requestExists: true, existingRequestStatus: 'shared', linkMode: 'approval',
      );
      expect(plan.status, JoinStatus.shared);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/collaboration/share_service_test.dart`
Expected: FAIL — `ShareLinkToken`, `buildJoinUrl`, `planJoin`, `JoinStatus` not found. (Also `appConfig` not found yet; Task 10 defines it — create it now.)

- [ ] **Step 3: Create app_config.dart**

`lib/core/config/app_config.dart`:

```dart
class AppConfig {
  /// Root domain for share links and Universal/App Links.
  ///
  /// HUMAN INPUT REQUIRED: set this to the real domain you own before
  /// deploying Tasks 10 and 11, and keep it in sync with the Android
  /// intent-filter, iOS entitlements, and hosting/.well-known files.
  static const String shareDomain = 'mynotes.example.com';
}

const appConfig = AppConfig();
```

- [ ] **Step 4: Create models**

`lib/features/collaboration/models/share_link.dart`:

```dart
class ShareLink {
  final String token;
  final String url;
  final String mode;
  final String noteTitle;

  const ShareLink({
    required this.token,
    required this.url,
    required this.mode,
    required this.noteTitle,
  });
}
```

`lib/features/collaboration/models/join_request.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  final String token;
  final String recipientUid;
  final String recipientName;
  final String recipientEmail;
  final String noteId;
  final String noteTitle;
  final String status;
  final DateTime createdAt;

  const JoinRequest({
    required this.token,
    required this.recipientUid,
    required this.recipientName,
    required this.recipientEmail,
    required this.noteId,
    required this.noteTitle,
    required this.status,
    required this.createdAt,
  });

  factory JoinRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return JoinRequest(
      token: doc.reference.parent.parent!.id,
      recipientUid: doc.id,
      recipientName: data['recipientName'] as String? ?? '',
      recipientEmail: data['recipientEmail'] as String? ?? '',
      noteId: data['noteId'] as String? ?? '',
      noteTitle: data['noteTitle'] as String? ?? 'Note',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
```

- [ ] **Step 5: Implement token, url, and plan helpers in share_service.dart**

Add to `lib/features/collaboration/services/share_service.dart` (imports: `dart:math` as `math`, `dart:convert` already added, `mynotes/core/config/app_config.dart`, the two new model files):

```dart
enum JoinStatus { notFound, ownerLink, alreadyShared, pending, approved, shared }

class JoinResult {
  final JoinStatus status;
  final String? noteTitle;
  const JoinResult(this.status, {this.noteTitle});
}

class ShareLinkToken {
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const int length = 22;

  static String generate({math.Random? random}) {
    final rng = random ?? math.Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
  }
}

String buildJoinUrl(String token) => 'https://${appConfig.shareDomain}/join/$token';

({JoinStatus status, String requestStatus}) planJoin({
  required bool linkExists,
  required bool isOwner,
  required bool alreadyShared,
  required bool requestExists,
  required String existingRequestStatus,
  required String linkMode,
}) {
  if (!linkExists) return (status: JoinStatus.notFound, requestStatus: '');
  if (isOwner) return (status: JoinStatus.ownerLink, requestStatus: '');
  if (alreadyShared) {
    return (
      status: JoinStatus.alreadyShared,
      requestStatus: existingRequestStatus,
    );
  }
  if (requestExists) {
    return switch (existingRequestStatus) {
      'shared' => (status: JoinStatus.shared, requestStatus: 'shared'),
      'approved' => (status: JoinStatus.approved, requestStatus: 'approved'),
      _ => (status: JoinStatus.pending, requestStatus: existingRequestStatus),
    };
  }
  if (linkMode == 'open') {
    return (status: JoinStatus.approved, requestStatus: 'approved');
  }
  return (status: JoinStatus.pending, requestStatus: 'pending');
}
```

- [ ] **Step 6: Implement createShareLink, revokeShareLink, joinSharedNote**

Add to `ShareService` (replace the placeholder `getShareableLink` at line 129):

```dart
  Future<ShareLink> createShareLink({
    required String uid,
    required Note note,
    required String mode,
  }) async {
    final token = ShareLinkToken.generate();
    await firestore.collection('shareLinks').doc(token).set({
      'ownerUid': uid,
      'noteId': note.id,
      'mode': mode,
      'noteTitlePlain': note.displayTitle,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    return ShareLink(
      token: token,
      url: buildJoinUrl(token),
      mode: mode,
      noteTitle: note.displayTitle,
    );
  }

  Future<void> revokeShareLink({required String token}) async {
    await firestore.collection('shareLinks').doc(token).delete();
  }

  Future<JoinResult> joinSharedNote({
    required String uid,
    required String token,
    required List<int> recipientPublicKey,
    required String recipientName,
    required String recipientEmail,
  }) async {
    final linkRef = firestore.collection('shareLinks').doc(token);
    final linkDoc = await linkRef.get();
    if (!linkDoc.exists) return const JoinResult(JoinStatus.notFound);
    final linkData = linkDoc.data()!;

    final ownerUid = linkData['ownerUid'] as String;
    final noteId = linkData['noteId'] as String;
    final mode = linkData['mode'] as String? ?? 'approval';
    final noteTitle = linkData['noteTitlePlain'] as String? ?? 'Note';

    if (ownerUid == uid) return const JoinResult(JoinStatus.ownerLink);

    final noteRef = firestore
        .collection('users')
        .doc(ownerUid)
        .collection('notes')
        .doc(noteId);
    final requestRef = linkRef.collection('requests').doc(uid);

    bool alreadyShared = false;
    try {
      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) return const JoinResult(JoinStatus.notFound);
      alreadyShared = true;
    } catch (_) {
      alreadyShared = false;
    }
    if (alreadyShared) return const JoinResult(JoinStatus.alreadyShared);

    final requestDoc = await requestRef.get();
    final plan = planJoin(
      linkExists: true,
      isOwner: false,
      alreadyShared: false,
      requestExists: requestDoc.exists,
      existingRequestStatus: requestDoc.exists
          ? (requestDoc.data()?['status'] as String? ?? 'pending')
          : '',
      linkMode: mode,
    );

    if (plan.requestStatus.isNotEmpty &&
        (!requestDoc.exists ||
            requestDoc.data()?['status'] != plan.requestStatus)) {
      await requestRef.set({
        'ownerUid': ownerUid,
        'noteId': noteId,
        'noteTitle': noteTitle,
        'recipientUid': uid,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'recipientPublicKey': base64Encode(recipientPublicKey),
        'status': plan.requestStatus,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    }

    return JoinResult(plan.status, noteTitle: noteTitle);
  }
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/collaboration/share_service_test.dart` then `flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 8: Commit**

```bash
git add lib/core/config/app_config.dart lib/features/collaboration/models lib/features/collaboration/services/share_service.dart test/features/collaboration/share_service_test.dart
git commit -m "feat(share): share-link and join-request data API"
```

---

### Task 4: Owner-side join request completion pipeline

**Files:**
- Modify: `lib/features/collaboration/services/share_service.dart`
- Modify: `lib/features/notes/providers/notes_providers.dart`

**Interfaces:**
- Consumes: `JoinRequest.fromDoc` (Task 3), `KeyManager.unwrapNoteKey`, `KeyManager.wrapNoteKeyForCollaborator` (Task 1), `buildJoinUrl` unused here.
- Produces (used by Tasks 8, 9):
  - `ShareService.watchOwnerJoinRequests(String ownerUid) → Stream<List<JoinRequest>>`
  - `ShareService.approveJoinRequest({required String ownerUid, required String token, required String recipientUid}) → Future<void>`
  - `ShareService.denyJoinRequest({required String token, required String recipientUid}) → Future<void>`
  - `ShareService.completeShareForRequest({required String ownerUid, required String token, required String recipientUid}) → Future<void>`
  - `ownerJoinRequestsProvider = StreamProvider.family<List<JoinRequest>, String>`

- [ ] **Step 1: Implement the four methods in ShareService**

Append to `ShareService`:

```dart
  Stream<List<JoinRequest>> watchOwnerJoinRequests(String ownerUid) {
    return firestore
        .collectionGroup('requests')
        .where('ownerUid', isEqualTo: ownerUid)
        .where('status', whereIn: ['pending', 'approved'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JoinRequest.fromDoc(doc))
            .toList());
  }

  Future<void> approveJoinRequest({
    required String ownerUid,
    required String token,
    required String recipientUid,
  }) async {
    await firestore
        .collection('shareLinks')
        .doc(token)
        .collection('requests')
        .doc(recipientUid)
        .update({'status': 'approved'});
    await completeShareForRequest(
      ownerUid: ownerUid,
      token: token,
      recipientUid: recipientUid,
    );
  }

  Future<void> denyJoinRequest({
    required String token,
    required String recipientUid,
  }) async {
    await firestore
        .collection('shareLinks')
        .doc(token)
        .collection('requests')
        .doc(recipientUid)
        .delete();
  }

  Future<void> completeShareForRequest({
    required String ownerUid,
    required String token,
    required String recipientUid,
  }) async {
    final linkRef = firestore.collection('shareLinks').doc(token);
    final requestRef = linkRef.collection('requests').doc(recipientUid);

    final linkDoc = await linkRef.get();
    if (!linkDoc.exists) {
      await requestRef.delete();
      return;
    }

    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) return;
    if (requestDoc.data()?['status'] == 'shared') return;
    final requestData = requestDoc.data()!;

    final recipientPublicKeyB64 =
        requestData['recipientPublicKey'] as String?;
    if (recipientPublicKeyB64 == null) return;

    final noteId = requestData['noteId'] as String?;
    if (noteId == null) return;

    final noteRef = firestore
        .collection('users')
        .doc(ownerUid)
        .collection('notes')
        .doc(noteId);
    final noteDoc = await noteRef.get();
    final data = noteDoc.data();
    if (data == null) return;

    final storedEncryptionVersion = (data['encryptionVersion'] as int?) ?? 0;
    final storedWrappedKey = data['wrappedKey'];

    final collaborators = List<String>.from(data['collaborators'] ?? []);
    final encryptedKeys = Map<String, String>.from(data['encryptedKeys'] ?? {});

    if (storedEncryptionVersion >= 1 && storedWrappedKey != null) {
      final noteKey = await keyManager
          .unwrapNoteKey((storedWrappedKey as Map).cast<String, String>());
      encryptedKeys[recipientUid] = await keyManager
          .wrapNoteKeyForCollaborator(
            noteKey: noteKey,
            recipientPublicKey: base64Decode(recipientPublicKeyB64),
          );
    }

    if (!collaborators.contains(recipientUid)) {
      collaborators.add(recipientUid);
    }

    await noteRef.update({
      'collaborators': collaborators,
      'encryptedKeys': encryptedKeys,
      'sharedBy': ownerUid,
      'sharedAt': Timestamp.fromDate(DateTime.now()),
    });
    await requestRef.update({'status': 'shared'});
  }
```

- [ ] **Step 2: Add the provider**

In `lib/features/notes/providers/notes_providers.dart`, add after `shareServiceProvider`:

```dart
final ownerJoinRequestsProvider =
    StreamProvider.family<List<JoinRequest>, String>((ref, ownerUid) {
  return ref.watch(shareServiceProvider).watchOwnerJoinRequests(ownerUid);
});
```

Add the import: `import 'package:mynotes/features/collaboration/models/join_request.dart';`

- [ ] **Step 3: Verify**

Run: `flutter analyze` then `flutter test`
Expected: clean; all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/collaboration/services/share_service.dart lib/features/notes/providers/notes_providers.dart
git commit -m "feat(share): owner-side join request completion pipeline"
```

---

### Task 5: Firestore security rules for shareLinks and requests

**Files:**
- Modify: `firestore.rules`
- Test: `tests/firestore.test.js`

**Interfaces:**
- Consumes: the document shapes from Tasks 3-4:
  - `shareLinks/{token}`: `ownerUid`, `noteId`, `mode`, `noteTitlePlain`, `createdAt`.
  - `shareLinks/{token}/requests/{recipientUid}`: `ownerUid`, `noteId`, `noteTitle`, `recipientUid`, `recipientName`, `recipientEmail`, `recipientPublicKey`, `status`, `createdAt`.
  - `users/{uid}`: `publicKey` base64 string.

- [ ] **Step 1: Write failing rules tests**

Append to `tests/firestore.test.js`:

```js
  it('allows any authenticated user to read another user publicKey', async () => {
    const dbA = testEnv.authenticatedContext('userA').firestore();
    const dbB = testEnv.authenticatedContext('userB').firestore();
    await dbB.collection('users').doc('userB').set({ email: 'b@x.com', publicKey: 'abc' });
    await assertSucceeds(dbA.collection('users').doc('userB').get());
  });

  it('allows owner to create a share link', async () => {
    const db = testEnv.authenticatedContext('owner').firestore();
    await db.collection('shareLinks').doc('token1').set({
      ownerUid: 'owner', noteId: 'note1', mode: 'approval',
      noteTitlePlain: 'My note', createdAt: new Date(),
    });
    await assertSucceeds(db.collection('shareLinks').doc('token1').get());
  });

  it('denies creating a share link as another user', async () => {
    const db = testEnv.authenticatedContext('owner').firestore();
    await assertFails(db.collection('shareLinks').doc('token1').set({
      ownerUid: 'someoneElse', noteId: 'note1', mode: 'approval',
      noteTitlePlain: 'x', createdAt: new Date(),
    }));
  });

  it('allows recipient to create a pending request', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    await dbOwner.collection('shareLinks').doc('token1').set({
      ownerUid: 'owner', noteId: 'note1', mode: 'approval', createdAt: new Date(),
    });
    const dbRecipient = testEnv.authenticatedContext('recipient').firestore();
    await dbRecipient.collection('shareLinks').doc('token1').collection('requests').doc('recipient').set({
      ownerUid: 'owner', noteId: 'note1', recipientUid: 'recipient',
      recipientPublicKey: 'abc', status: 'pending', createdAt: new Date(),
    });
    await assertSucceeds(dbRecipient.collection('shareLinks').doc('token1').collection('requests').doc('recipient').get());
  });

  it('allows recipient to auto-approve on an open-mode link', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    await dbOwner.collection('shareLinks').doc('token1').set({
      ownerUid: 'owner', noteId: 'note1', mode: 'open', createdAt: new Date(),
    });
    const dbRecipient = testEnv.authenticatedContext('recipient').firestore();
    await dbRecipient.collection('shareLinks').doc('token1').collection('requests').doc('recipient').set({
      ownerUid: 'owner', noteId: 'note1', recipientUid: 'recipient',
      recipientPublicKey: 'abc', status: 'approved', createdAt: new Date(),
    });
    await assertSucceeds(dbRecipient.collection('shareLinks').doc('token1').collection('requests').doc('recipient').get());
  });

  it('denies recipient creating a request for another user', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    await dbOwner.collection('shareLinks').doc('token1').set({
      ownerUid: 'owner', noteId: 'note1', mode: 'approval', createdAt: new Date(),
    });
    const dbRecipient = testEnv.authenticatedContext('recipient').firestore();
    await assertFails(dbRecipient.collection('shareLinks').doc('token1').collection('requests').doc('someoneElse').set({
      ownerUid: 'owner', noteId: 'note1', recipientUid: 'someoneElse',
      recipientPublicKey: 'abc', status: 'pending', createdAt: new Date(),
    }));
  });

  it('allows owner to read own requests via collectionGroup', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    await dbOwner.collection('shareLinks').doc('token1').collection('requests').doc('r1').set({
      ownerUid: 'owner', noteId: 'note1', recipientUid: 'r1', status: 'pending', createdAt: new Date(),
    });
    await assertSucceeds(dbOwner.collectionGroup('requests').where('ownerUid', '==', 'owner').get());
  });

  it('denies non-owner from updating a request status', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    await dbOwner.collection('shareLinks').doc('token1').collection('requests').doc('r1').set({
      ownerUid: 'owner', noteId: 'note1', recipientUid: 'r1', status: 'pending', createdAt: new Date(),
    });
    const dbIntruder = testEnv.authenticatedContext('intruder').firestore();
    await assertFails(dbIntruder.collection('shareLinks').doc('token1').collection('requests').doc('r1').update({ status: 'shared' }));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx @firebase/rules-unit-testing` is not a CLI; run with node + mocha. From repo root:

```bash
npx mocha tests/firestore.test.js --timeout 20000
```

(If mocha is not installed, run `npm i -D mocha` first — the test file is already set up for mocha.)
Expected: the new `shareLinks`/`requests` tests FAIL with permission errors.

- [ ] **Step 3: Add rules**

Append inside `service cloud.firestore { match /databases/{database}/documents { ... } }` (after the existing version block):

```firestore
    // Share links: anyone authenticated who has the (unguessable) token path
    // may read; only the owner writes.
    match /shareLinks/{token} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.ownerUid == request.auth.uid;
      allow update, delete: if request.auth != null
        && resource.data.ownerUid == request.auth.uid;

      match /requests/{recipientUid} {
        allow read: if request.auth != null
          && (request.auth.uid == resource.data.ownerUid
              || request.auth.uid == recipientUid);
        allow create: if request.auth != null
          && request.auth.uid == recipientUid
          && request.resource.data.ownerUid == get(/databases/$(database)/documents/shareLinks/$(token)).data.ownerUid
          && request.resource.data.status in ['pending', 'approved'];
        allow update: if request.auth != null
          && (request.auth.uid == resource.data.ownerUid
              || request.auth.uid == recipientUid);
        allow delete: if request.auth != null
          && request.auth.uid == resource.data.ownerUid;
      }
    }

    // Collection group: owner watches join requests across their links
    match /{path=**}/requests/{recipientUid} {
      allow read: if request.auth != null
        && resource.data.ownerUid == request.auth.uid;
    }
```

- [ ] **Step 4: Run rules tests to verify they pass**

Run: `npx mocha tests/firestore.test.js --timeout 20000`
Expected: all tests pass (existing + new).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tests/firestore.test.js
git commit -m "feat(rules): secure shareLinks and join request documents"
```

---

### Task 6: Deep-link parsing + pending-link store + join processor

**Files:**
- Modify: `pubspec.yaml` (add `app_links`)
- Create: `lib/core/deeplinks/join_link_handler.dart`
- Create: `lib/core/deeplinks/pending_link_store.dart`
- Create: `lib/features/collaboration/services/join_link_processor.dart`
- Modify: `lib/features/notes/providers/notes_providers.dart`
- Test: `test/core/deeplinks/join_link_handler_test.dart`

**Interfaces:**
- Consumes: `JoinStatus`/`JoinResult`/`ShareService.joinSharedNote` (Task 3), `KeyManager.getMyPublicKey` (Task 1), `authStateProvider`/`currentUserProvider`.
- Produces (used by Task 9):
  - `JoinLinkHandler.tokenFromUri(Uri uri) → String?`
  - `PendingLinkStore.save(String url)`, `.read() → Future<String?>`, `.clear()`
  - `joinResultProvider = StateProvider<JoinResult?>`
  - `joinLinkProcessorProvider = Provider<JoinLinkProcessor>`
  - `JoinLinkProcessor.init(Stream<Uri> uriLinkStream)`, `.handleUri(Uri uri)`, `.processPending()`

- [ ] **Step 1: Add dependencies**

Run: `flutter pub add app_links`

- [ ] **Step 2: Write failing parser test**

`test/core/deeplinks/join_link_handler_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/deeplinks/join_link_handler.dart';

void main() {
  group('JoinLinkHandler.tokenFromUri', () {
    test('extracts token from /join/{token}', () {
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/join/abc123')),
        'abc123',
      );
    });

    test('rejects non-join paths', () {
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/other')),
        isNull,
      );
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/')),
        isNull,
      );
    });

    test('rejects missing token', () {
      expect(
        JoinLinkHandler.tokenFromUri(Uri.parse('https://example.com/join/')),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/deeplinks/join_link_handler_test.dart`
Expected: FAIL — type not found.

- [ ] **Step 4: Implement join_link_handler.dart and pending_link_store.dart**

`lib/core/deeplinks/join_link_handler.dart`:

```dart
class JoinLinkHandler {
  static String? tokenFromUri(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final segments = uri.pathSegments;
    if (segments.length == 2 && segments[0] == 'join' && segments[1].isNotEmpty) {
      return segments[1];
    }
    return null;
  }
}
```

`lib/core/deeplinks/pending_link_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class PendingLinkStore {
  static const String _key = 'pending_join_link';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<void> save(String url) async {
    final prefs = await _instance();
    await prefs.setString(_key, url);
  }

  static Future<String?> read() async => (await _instance()).getString(_key);

  static Future<void> clear() async {
    final prefs = await _instance();
    await prefs.remove(_key);
  }
}
```

- [ ] **Step 5: Implement the join link processor**

`lib/features/collaboration/services/join_link_processor.dart`:

```dart
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/deeplinks/join_link_handler.dart';
import 'package:mynotes/core/deeplinks/pending_link_store.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';

class JoinLinkProcessor {
  final ShareService shareService;
  final KeyManager keyManager;
  final AuthUser? Function() currentUser;
  final void Function(JoinResult) onResult;

  JoinLinkProcessor({
    required this.shareService,
    required this.keyManager,
    required this.currentUser,
    required this.onResult,
  });

  Future<void> handleUri(Uri uri) async {
    final token = JoinLinkHandler.tokenFromUri(uri);
    if (token == null) return;
    final user = currentUser();
    if (user == null || user.uid.isEmpty) {
      await PendingLinkStore.save(uri.toString());
      return;
    }
    await _process(token, user);
  }

  Future<void> processPending() async {
    final stored = await PendingLinkStore.read();
    if (stored == null) return;
    await PendingLinkStore.clear();
    final uri = Uri.tryParse(stored);
    if (uri == null) return;
    final token = JoinLinkHandler.tokenFromUri(uri);
    if (token == null) return;
    final user = currentUser();
    if (user == null || user.uid.isEmpty) return;
    await _process(token, user);
  }

  Future<void> _process(String token, AuthUser user) async {
    final publicKey = await keyManager.getMyPublicKey();
    final result = await shareService.joinSharedNote(
      uid: user.uid,
      token: token,
      recipientPublicKey: publicKey,
      recipientName: user.displayName ?? '',
      recipientEmail: user.email,
    );
    onResult(result);
  }
}
```

- [ ] **Step 6: Wire providers**

In `lib/features/notes/providers/notes_providers.dart`:

```dart
import 'package:mynotes/core/deeplinks/pending_link_store.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/collaboration/services/join_link_processor.dart';

final joinResultProvider = StateProvider<JoinResult?>((ref) => null);

final joinLinkProcessorProvider = Provider<JoinLinkProcessor>((ref) {
  return JoinLinkProcessor(
    shareService: ref.watch(shareServiceProvider),
    keyManager: ref.watch(keyManagerProvider),
    currentUser: () => ref.read(currentUserProvider),
    onResult: (result) => ref.read(joinResultProvider.notifier).state = result,
  );
});
```

`keyManagerProvider` already exists in `lib/core/encryption/providers/encryption_providers.dart` (already imported in this file).

- [ ] **Step 7: Run tests and analyze**

Run: `flutter test test/core/deeplinks/join_link_handler_test.dart` then `flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/deeplinks lib/features/collaboration/services/join_link_processor.dart lib/features/notes/providers/notes_providers.dart test/core/deeplinks
git commit -m "feat(share): deep-link parsing and pending join processing"
```

---

### Task 7: Owner share-sheet link UI

**Files:**
- Modify: `lib/features/notes/presentation/note_editor_view.dart`
- Modify: `pubspec.yaml` (add `share_plus`)

**Interfaces:**
- Consumes: `ShareService.createShareLink`, `revokeShareLink` (Task 3), `ShareLink` model, `shareServiceProvider`.
- Produces: `_ShareSheet.onCreateLink(String mode) → Future<ShareLink>` and `_ShareSheet.onRevokeLink(String token) → Future<void>` callbacks wired in `_showShareSheet`.

- [ ] **Step 1: Add share_plus**

Run: `flutter pub add share_plus`

- [ ] **Step 2: Extend _ShareSheet widget**

In `note_editor_view.dart`, add to `_ShareSheet`:

```dart
  final Future<ShareLink> Function(String mode) onCreateLink;
  final Future<void> Function(String token) onRevokeLink;
```

and to `_ShareSheetState` state fields:

```dart
  String _linkMode = 'approval';
  ShareLink? _link;
  bool _isGenerating = false;
  bool _isRevoking = false;
```

Add methods:

```dart
  Future<void> _generateLink() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final link = await widget.onCreateLink(_linkMode);
      if (!mounted) return;
      setState(() => _link = link);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _copyLink() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _shareLink() async {
    final link = _link;
    if (link == null) return;
    await SharePlus.instance.share(ShareParams(text: link.url));
  }

  Future<void> _revokeLink() async {
    final link = _link;
    if (link == null) return;
    setState(() {
      _isRevoking = true;
      _error = null;
    });
    try {
      await widget.onRevokeLink(link.token);
      if (!mounted) return;
      setState(() => _link = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link revoked')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }
```

Add imports at the top of the file: `import 'package:flutter/services.dart';` and `import 'package:share_plus/share_plus.dart';` and `import 'package:mynotes/features/collaboration/models/share_link.dart';`.

In `_ShareSheetState.build`, after the collaborators list and before the closing `]` of the Column, insert the link section:

```dart
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.link, color: notely.text2, size: 18),
              const SizedBox(width: 8),
              Text(
                'Share via link',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Anyone with the link can request access. You approve before they see the note.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: notely.text3,
                ),
          ),
          const SizedBox(height: 12),
          if (_link == null) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'approval',
                  label: Text('Require approval'),
                ),
                ButtonSegment(value: 'open', label: Text('Auto-approve')),
              ],
              selected: {_linkMode},
              onSelectionChanged: (selection) {
                setState(() => _linkMode = selection.first);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generateLink,
                icon: _isGenerating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link_rounded),
                label: const Text('Create share link'),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: notely.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _link!.url,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: notely.text2,
                            fontFamily: 'JetBrains Mono',
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: _shareLink,
                    icon: const Icon(Icons.ios_share, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isRevoking ? null : _revokeLink,
              icon: const Icon(Icons.link_off_rounded, size: 16),
              label: const Text('Revoke link'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
```

- [ ] **Step 3: Wire callbacks in _showShareSheet**

In `_showShareSheet` (line 588), pass the two new callbacks into the `_ShareSheet` constructor:

```dart
        onCreateLink: (mode) {
          final shareService = ref.read(shareServiceProvider);
          return shareService.createShareLink(
            uid: widget.authUser.uid,
            note: note,
            mode: mode,
          );
        },
        onRevokeLink: (token) {
          return ref.read(shareServiceProvider).revokeShareLink(token: token);
        },
```

- [ ] **Step 4: Verify**

Run: `flutter analyze` then `flutter test`
Expected: clean; all pass.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/notes/presentation/note_editor_view.dart
git commit -m "feat(share): link creation UI in note share sheet"
```

---

### Task 8: Owner join-request management UI

**Files:**
- Modify: `lib/features/account/presentation/account_sheet.dart`

**Interfaces:**
- Consumes: `ownerJoinRequestsProvider` (Task 4), `ShareService.approveJoinRequest`/`denyJoinRequest`.

- [ ] **Step 1: Add the pending-requests section**

In `account_sheet.dart` build, after the sync-status `Container` (line 72) and before the Appearance `_SheetRow`, add a section that watches pending requests for the current user:

```dart
          const SizedBox(height: 14),
          _JoinRequestsSection(uid: _uid(ref)),
```

Add a private widget at the end of the file:

```dart
class _JoinRequestsSection extends ConsumerWidget {
  final String uid;
  const _JoinRequestsSection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final requests = ref.watch(ownerJoinRequestsProvider(uid)).valueOrNull ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Join requests',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: notely.text3,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ...requests.map(
          (request) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: notely.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.recipientName.isEmpty ? request.recipientEmail : request.recipientName} wants to join',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '"${request.noteTitle}"',
                  style: TextStyle(fontSize: 12, color: notely.text3),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await ref.read(shareServiceProvider).approveJoinRequest(
                              ownerUid: uid,
                              token: request.token,
                              recipientUid: request.recipientUid,
                            );
                      },
                      child: const Text('Approve'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(shareServiceProvider).denyJoinRequest(
                              token: request.token,
                              recipientUid: request.recipientUid,
                            );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Deny'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze` then `flutter test`
Expected: clean; all pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/account/presentation/account_sheet.dart
git commit -m "feat(share): join request management in account sheet"
```

---

### Task 9: Recipient join UX + home-screen wiring

**Files:**
- Modify: `lib/features/notes/presentation/notes_home_view.dart`
- Modify: `lib/features/notes/providers/notes_providers.dart`

**Interfaces:**
- Consumes: `joinLinkProcessorProvider`, `joinResultProvider` (Task 6), `ShareService.watchOwnerJoinRequests`/`completeShareForRequest` (Task 4), `AppLinks().uriLinkStream`.

- [ ] **Step 1: Wire live-link subscription, pending processing, and auto-completion**

In `notes_home_view.dart` `_NotesHomeViewState`:

Add fields and import:

```dart
  StreamSubscription<Uri>? _uriSub;
  StreamSubscription<List<JoinRequest>>? _requestSub;
```

Add imports: `import 'dart:async';`, `import 'package:app_links/app_links.dart';`, `import 'package:mynotes/features/collaboration/models/join_request.dart';`.

Replace the `initState` post-frame callback (lines 40-48):

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(shareServiceProvider).ensureUserProfile(
              uid: widget.authUser.uid,
              email: widget.authUser.email,
              displayName: widget.authUser.displayName,
            );
        await ref.read(joinLinkProcessorProvider).processPending();
      } catch (_) {}
      _watchOwnerRequests();
      _listenForLinks();
    });
  }

  void _listenForLinks() {
    _uriSub = AppLinks().uriLinkStream.listen((uri) {
      ref.read(joinLinkProcessorProvider).handleUri(uri);
    });
  }

  void _watchOwnerRequests() {
    _requestSub =
        ref.read(shareServiceProvider).watchOwnerJoinRequests(widget.authUser.uid).listen((requests) async {
      for (final request in requests.where((r) => r.status == 'approved')) {
        try {
          await ref.read(shareServiceProvider).completeShareForRequest(
                ownerUid: widget.authUser.uid,
                token: request.token,
                recipientUid: request.recipientUid,
              );
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _uriSub?.cancel();
    _requestSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }
```

- [ ] **Step 2: React to join results with a dialog**

In `_NotesHomeViewState.build`, add a `ref.listen` at the top of build (after `final notely = ...` if present — place it as the first line of `build`):

```dart
    ref.listen<JoinResult?>(joinResultProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(joinResultProvider.notifier).state = null;
      });
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share link'),
          content: Text(_joinMessage(next)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
```

Add the message helper:

```dart
  String _joinMessage(JoinResult result) {
    final title = result.noteTitle ?? '';
    return switch (result.status) {
      JoinStatus.notFound => 'This link is invalid or has expired.',
      JoinStatus.ownerLink => 'You opened your own share link.',
      JoinStatus.alreadyShared => 'This note is already shared with you.',
      JoinStatus.pending => 'Request sent. Waiting for the owner to approve your request to join "$title".',
      JoinStatus.approved => 'Almost there — the owner will share "$title" with you shortly.',
      JoinStatus.shared => '"$title" is now shared with you.',
    };
  }
```

Add the import: `import 'package:mynotes/features/collaboration/services/share_service.dart';`

- [ ] **Step 3: Verify**

Run: `flutter analyze` then `flutter test`
Expected: clean; all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/notes/presentation/notes_home_view.dart lib/features/notes/providers/notes_providers.dart
git commit -m "feat(share): recipient join UX and owner auto-completion"
```

---

### Task 10: Native deep-link config (gated on human inputs)

> HUMAN INPUT REQUIRED: set `appConfig.shareDomain` to the real domain, provide the Apple Team ID (for AASA), and the Android release-keystore SHA-256 fingerprint (from `keytool -list -v -keystore <release.jks> -alias <alias>`). Do not guess these. If any value is missing, stop and ask the user.

**Files:**
- Modify: `lib/core/config/app_config.dart` (set real domain)
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `ios/Runner/Runner.entitlements`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (add entitlements + signing)

- [ ] **Step 1: Android intent-filter**

In `android/app/src/main/AndroidManifest.xml`, inside the `<activity android:name=".MainActivity" ...>` element, after the existing `<intent-filter>` (lines 26-29), add:

```xml
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="YOUR_REAL_DOMAIN"/>
            </intent-filter>
```

Replace `YOUR_REAL_DOMAIN` with the actual domain value from `appConfig.shareDomain`.

- [ ] **Step 2: iOS entitlements**

Create `ios/Runner/Runner.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:YOUR_REAL_DOMAIN</string>
	</array>
</dict>
</plist>
```

Replace `YOUR_REAL_DOMAIN` with the real domain.

- [ ] **Step 3: Wire entitlements into the Xcode project**

In `ios/Runner.xcodeproj/project.pbxproj`, add a PBXFileReference for `Runner.entitlements` and set `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` on all three Runner build configurations. Follow the same pattern used when `PrivacyInfo.xcprivacy` was added (PBXBuildFile is not needed for entitlements; only the file reference and the build setting). Verify the entitlements file appears under the Runner group.

- [ ] **Step 4: Verify**

Run: `flutter analyze` and `flutter build apk --debug` (or `flutter build ios --no-codesign` if on macOS)
Expected: builds succeed. Note that App/Universal Links will only resolve on a real device after the `.well-known` files from Task 11 are live and the Android app is signed with the release keystore.

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/app_config.dart android/app/src/main/AndroidManifest.xml ios/Runner/Runner.entitlements ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(share): native universal/app link configuration"
```

---

### Task 11: Web landing page + Firebase Hosting + well-known files (gated on human inputs)

> HUMAN INPUT REQUIRED: the real domain, Apple Team ID, Android release-keystore SHA-256 fingerprint, and (once the apps are live) the App Store / Google Play URLs. If any are missing, stop and ask.

**Files:**
- Create: `hosting/firebase.json`
- Create: `hosting/public/index.html`
- Create: `hosting/public/join/index.html`
- Create: `hosting/public/.well-known/apple-app-site-association`
- Create: `hosting/public/.well-known/assetlinks.json`

- [ ] **Step 1: Landing page**

`hosting/public/index.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Mynotes</title>
  <style>
    body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; background: #0d1117; color: #e6edf3; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
    .card { text-align: center; max-width: 420px; padding: 40px 24px; }
    h1 { font-size: 28px; margin-bottom: 8px; }
    p { color: #9da7b3; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Mynotes</h1>
    <p>Private, end-to-end encrypted notes. Get the app to start writing.</p>
  </div>
</body>
</html>
```

`hosting/public/join/index.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Join a note · Mynotes</title>
  <style>
    body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; background: #0d1117; color: #e6edf3; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
    .card { text-align: center; max-width: 440px; padding: 40px 24px; }
    h1 { font-size: 24px; margin-bottom: 10px; }
    p { color: #9da7b3; line-height: 1.6; margin: 6px 0; }
    .badge { display: inline-block; margin: 14px 6px 0; padding: 12px 20px; border-radius: 10px; background: #238636; color: #fff; text-decoration: none; font-weight: 600; }
  </style>
</head>
<body>
  <div class="card">
    <h1>You've been invited to a note</h1>
    <p>A friend wants to share a note with you on Mynotes.</p>
    <p>To join: install the app, create an account, then tap the link again.</p>
    <a class="badge" href="YOUR_APP_STORE_URL">Download on the App Store</a>
    <a class="badge" href="YOUR_PLAY_STORE_URL">Get it on Google Play</a>
  </div>
</body>
</html>
```

Replace `YOUR_APP_STORE_URL` / `YOUR_PLAY_STORE_URL` with the real store URLs once published (or leave as `#` until then).

- [ ] **Step 2: Hosting config**

`hosting/firebase.json`:

```json
{
  "hosting": {
    "public": "public",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "/join/**", "destination": "/join/index.html" }
    ]
  }
}
```

- [ ] **Step 3: Well-known files**

`hosting/public/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["YOUR_TEAM_ID.com.flutter.mynotes"],
        "components": [
          { "/": "/join/*", "comment": "Matches /join/{token}" }
        ]
      }
    ]
  }
}
```

Replace `YOUR_TEAM_ID` with the Apple Team ID. The bundle ID is `com.flutter.mynotes` (verify against the Runner project).

`hosting/public/.well-known/assetlinks.json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.flutter.mynotes",
      "sha256_cert_fingerprints": ["YOUR_RELEASE_SHA256"]
    }
  }
]
```

Replace `YOUR_RELEASE_SHA256` with the release-keystore fingerprint (note: the current release signing still uses the debug keystore — see `android/app/build.gradle.kts:41`; fix signing before publishing).

- [ ] **Step 4: Deploy**

Run: `firebase deploy --only hosting`
Expected: hosting goes live; verify `https://YOUR_DOMAIN/.well-known/apple-app-site-association` and `https://YOUR_DOMAIN/.well-known/assetlinks.json` are served with the correct content-type (`application/json`; AASA should be served as `application/json` with no newline issues — add a `headers` rule if needed).

- [ ] **Step 5: Commit**

```bash
git add hosting/
git commit -m "feat(share): web landing page and deep-link verification files"
```

---

## Self-Review

**Spec coverage:** Every spec section maps to a task: crypto fix → Task 1; publicKey publishing → Task 2; shareLinks/requests model + open/approval modes → Tasks 3 & 5; owner-mediated link, no key in link → Tasks 3-4; deep-link infra (Universal/App Links) → Tasks 6, 10; web fallback landing page → Task 11; recipient must be logged in → Task 6 pending store + Task 9; account-sheet join requests → Task 8; owner auto-completion on next sync → Tasks 4 & 9; revoke → Tasks 3 & 7. The spec's landing page is static/generic (no owner email) — matches Task 11.

**Placeholder scan:** No "TBD/TODO/implement later" steps. The only placeholders are the explicit HUMAN INPUT values (domain, Team ID, fingerprint, store URLs) in Tasks 10-11, which are genuine external inputs that the plan flags as hard gates with an instruction to stop and ask rather than guess.

**Type consistency:** `JoinStatus`/`JoinResult`/`planJoin` (Task 3) are used identically in Tasks 6 and 9. `JoinRequest` (Task 3 model) is used by Tasks 4, 8, 9. `ShareLink` (Task 3 model) is used by Task 7. `watchOwnerJoinRequests`/`completeShareForRequest`/`approveJoinRequest`/`denyJoinRequest` signatures match across Tasks 4, 8, 9. `joinSharedNote` signature (Task 3) matches its Task 6 call. `getMyPublicKey` (Task 1) is used in Tasks 2, 6. No naming drift.

**Known follow-ups (out of scope, noted):** recipient-side "still waiting" indicator is a one-time dialog only; the shared feed auto-populates on completion. Firestore indexes: the `watchOwnerJoinRequests` query (`collectionGroup('requests')` with `ownerUid` equality + `status` in-array) needs a composite index created in the Firebase console (deployment note). Store URLs and release signing are documented human actions.
