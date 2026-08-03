# Shareable Links for Collaboration — Design

## Overview

Replace the "coming soon" `getShareableLink()` placeholder (`lib/features/collaboration/services/share_service.dart:129`) with a real shareable-link collaboration feature. A note owner generates a link that any registered user can open to join the note as a collaborator, with a per-link toggle between instant join and owner-approved join. Recipients without the app are routed through a web landing page to install the app and create an account first.

This feature is built on the existing email-based collaboration flow (`share_service.dart`, `note_editor_view.dart` share sheet) and fixes the latent E2EE key-wrapping bug that currently prevents shared notes from being decrypted by collaborators.

## Scope

**In scope**
- Link-based invite + request-access (per-link mode toggle: `open` / `approval`).
- Universal/App Links deep linking (iOS + Android) with a web landing page fallback for recipients who don't have the app.
- Recipient must be a registered, logged-in user to accept. Flow is always: download app → create account → tap invite link again → accept.
- Owner-side "Join requests" surface with Approve / Decline.
- Link revocation.
- Fix to the E2EE key-wrapping scheme (X25519 ECDH) so shared notes actually decrypt.
- Security rules for the new collections.
- Unit, widget, and rules tests.

**Out of scope (explicitly not v1)**
- "Anyone-with-the-link can view" (link carries a key; weakens E2EE). Rejected in brainstorm.
- Instant join while the owner's device is offline (impossible under E2EE — the owner's device must wrap the key). Joining completes on the owner's next sync.
- Previewing the note title in the invite card (titles are encrypted).
- Unauthenticated recipients joining (must create an account first).

## Prerequisite: fix the E2EE key-wrapping bug

### Current (broken) behavior
`KeyManager.deriveSharingKey(uid)` (`lib/core/encryption/key_manager.dart:152`) computes `sha256(masterKey ‖ uid)` using the *caller's* master key.

- Owner wraps: `sha256(ownerMasterKey ‖ recipientUid)` (`wrapNoteKeyForCollaborator`, line 125).
- Recipient unwraps: `sha256(recipientMasterKey ‖ ownerUid)` (`unwrapCollaboratorNoteKey` → `deriveSharingKey(ownerUid)`, lines 140/144).

These differ (different master keys, reversed inputs), so shared-note content can never be decrypted. `_decryptSharedNote` (`lib/features/notes/data/notes_service.dart:422`) swallows the failure and returns the encrypted note.

### Fix: deterministic X25519 keypairs
- Derive a deterministic X25519 keypair per user from their master key (seed = master key bytes) using the `cryptography` package (already a dependency).
- Store the **public key** in the user profile doc `users/{uid}` field `publicKey`.
- Owner wraps the note key with `ECDH(ownerPrivateKey, recipientPublicKey)` → shared secret → AES-256-GCM encrypt note key.
- Recipient unwraps with `ECDH(recipientPrivateKey, ownerPublicKey)` → same secret (ECDH symmetry) → decrypt.
- Server sees only public keys and wrapped ciphertext. E2EE claim preserved.

### Implementation notes
- Replace the internals of `wrapNoteKeyForCollaborator`, `unwrapCollaboratorNoteKey`, and `deriveSharingKey`; keep their signatures where possible.
- `ShareService.shareNote` and the new request-approval path must fetch the recipient's public key from `users/{recipientUid}` before wrapping.
- `ensureUserProfile` must write `publicKey` on account creation / login so the field exists for every user.
- No data migration required (pre-launch; no real shared notes exist).
- `canUseBiometrics`-style failure handling: if a collaborator's public key is missing, fall back to the existing "add as collaborator without key" behavior and surface a warning.

## Data model (Firestore)

### `shareLinks/{token}` (top-level collection)
```
token: string                 // 32 random bytes, base64url — the capability
ownerUid: string
noteId: string
mode: 'open' | 'approval'
status: 'open' | 'revoked'
createdByEmail: string
createdAt: Timestamp
```

### `shareLinks/{token}/requests/{recipientUid}`
```
recipientUid: string
recipientEmail: string
ownerUid: string               // denormalized for rule checks + owner queries
noteId: string                 // denormalized
status: 'pending' | 'approved' | 'declined'
createdAt: Timestamp
```

The link URL format is `https://<domain>/s/<token>`. The token never contains key material.

## Flows

### Owner: generate a link
1. In the share sheet (`_ShareSheet`, `note_editor_view.dart:1671`), add a "Copy share link" / "Share via…" action with a mode toggle: **Anyone with link** (`open`) vs **Require approval** (`approval`).
2. Generate token; write `shareLinks/{token}` (`status: open`).
3. Copy `https://<domain>/s/<token>` to the clipboard and/or open the native share sheet (via `share_plus`).
4. The share sheet lists the note's active links with a **Revoke** action (sets `status: revoked`; the link stops resolving).

### Owner: approve requests
1. Account sheet gains a **Join requests** row (badge = count of pending requests across the owner's notes).
2. Request list shows owner email + note (owner-visible only). Approve → owner's device unwraps the note key, wraps it for the requester's public key, adds requester UID to `collaborators`, sets request `approved`. Decline → request `declined`.
3. `mode: 'open'` requests are auto-approved on the owner's next app sync (no manual step).

### Recipient: accept
1. Tapping the link opens the app (Universal/App Links). If not installed, the web landing page shows (see below).
2. If not authenticated, the incoming token is buffered; after successful login/registration the invite flow resumes automatically.
3. Resolve `shareLinks/{token}` → if `status: revoked` or missing → "This invite is no longer valid." If the recipient is already a collaborator → "You already have access to this note." If recipient == owner → blocked.
4. Show invite card: *"<ownerEmail> invited you to collaborate on a note"* (no title — titles are encrypted) → **Accept**.
5. Accept writes `shareLinks/{token}/requests/{recipientUid}`:
   - `mode: 'open'` → `status: pending` with auto-approval semantics (owner's next sync approves).
   - `mode: 'approval'` → `status: pending`; UI shows "Request sent — you'll get access when the owner approves."
6. Once approved, the note appears in the recipient's feed via the existing `getSharedNotes` collectionGroup query (`notes_service.dart:397`), now decryptable.

### Web landing page (recipient without the app)
- Hosted at `https://<domain>/s/<token>` via Firebase Hosting on the same domain.
- The page is **static** (no Firestore reads — the rules require auth to read `shareLinks`, and the page must work for unauthenticated visitors). Generic copy: *"You've been invited to collaborate on a note in Notely"* + **Get it on the App Store** / **Get it on Google Play** buttons + "After installing and creating an account, tap the invite link again."
- The owner's email is shown only **inside** the app on the invite card, after the recipient has logged in and the app has resolved the token with auth.
- The page never exposes the note or keys.
- Store listing URLs are placeholders (filled when the store listings exist — human input).

## Deep-link infrastructure

### App side
- Add `app_links` package (and `share_plus` for the native share sheet; `clipboard` via existing Flutter services).
- iOS: add **Associated Domains** entitlement `applinks:<domain>` to the Runner target in `project.pbxproj`; register the capability in the Apple Developer portal (provisioning profile) — human step.
- Android: add an intent filter in `AndroidManifest.xml` with `android:autoVerify="true"`, host `<domain>`, path `/s/*`.

### Web side (Firebase Hosting)
- `/.well-known/apple-app-site-association` → `{ "applinks": { "appID": "<TEAMID>.<bundleID>", "paths": ["/s/*"] } }`.
- `/.well-known/assetlinks.json` → SHA-256 fingerprint of the Android **release signing keystore**.
- `/s/<token>` landing page.

### Required human inputs
- The actual `<domain>` (verified, HTTPS, controlled by the developer).
- Apple Team ID.
- Android release keystore SHA-256 fingerprint (depends on the release-signing setup from the submission audit — still pending).
- App Store / Play Store listing URLs (post-submission).

## Security rules (`firestore.rules`)

```
match /shareLinks/{token} {
  allow create: if request.auth != null
    && request.resource.data.ownerUid == request.auth.uid;
  allow read: if request.auth != null
    && resource.data.status == 'open';
  allow update, delete: if request.auth != null
    && resource.data.ownerUid == request.auth.uid;
}

match /shareLinks/{token}/requests/{recipientUid} {
  allow create: if request.auth != null
    && request.auth.uid == recipientUid
    && request.resource.data.status == 'pending';
  allow read: if request.auth != null
    && (request.auth.uid == resource.data.ownerUid
        || request.auth.uid == recipientUid);
  allow update, delete: if request.auth != null
    && request.auth.uid == resource.data.ownerUid;
}
```

`users/{uid}` rules already permit owner writes and authenticated reads; the profile simply gains the `publicKey` field.

## Error handling / edge cases

- Revoked or missing link → "This invite is no longer valid."
- Already a collaborator → "You already have access to this note."
- Recipient is the owner → blocked.
- Owner offline at accept → request stays `pending`; approved on the owner's next sync (`open` mode auto-approves).
- Note deleted after link created → invite resolves but note fetch fails → "This note is no longer available."
- Missing collaborator public key → degrade gracefully (share without key wrap + warning).

## Testing

- **Unit** (`test/`):
  - X25519 keypair determinism (same seed → same keypair) and wrap/unwrap roundtrip across two derived keypairs (proves the crypto fix).
  - Token generation: uniqueness and entropy.
  - Request state machine: `pending → approved | declined`; revoke prevents resolution.
  - `ShareService`: public-key wrap path for `shareNote` and request approval.
- **Widget** (`test/`):
  - Owner: generate link copies URL; join-requests list renders pending requests; Approve invokes the service.
  - Recipient: invite card for `open` / `approval` / revoked links; buffered-token-after-login resume.
- **Rules** (`tests/firestore.test.js`): shareLinks create/read/revoke and requests lifecycle, plus collaborator-only access checks.

## Non-goals reminder

- No link-key sharing (Option B). No note-title preview in invites. No unauthenticated joining. No owner-offline instant join.
