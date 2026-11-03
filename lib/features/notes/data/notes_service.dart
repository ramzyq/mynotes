import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/notes/data/comment.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/moderation/models/content_report.dart';

/// Thrown for problems the user can act on; [message] is safe to display.
class NoteException implements Exception {
  const NoteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A decrypted entry from a note's version history.
class NoteVersion {
  const NoteVersion({
    required this.id,
    required this.versionNumber,
    required this.createdAt,
    this.title,
    this.content,
    this.decryptionFailed = false,
  });

  final String id;
  final int versionNumber;
  final DateTime createdAt;
  final String? title;
  final String? content;
  final bool decryptionFailed;
}

class NotesService {
  final FirebaseFirestore firestore;
  final CryptoService crypto;
  final KeyManager keyManager;

  NotesService({
    required this.firestore,
    required this.crypto,
    required this.keyManager,
  });

  static const versionInterval = Duration(minutes: 5);
  static const maxVersions = 50;
  static const _pinIterations = 100000;
  static const _legacyPinIterations = 10000;

  // In-memory caches; all cleared on sign-out via [clearCaches].
  final _decrypted = <String, ({String fingerprint, Note note})>{};
  final _noteKeys = <String, ({int gen, SecretKey key})>{};
  final _pinKeks = <String, SecretKey>{};
  final _publicKeys = <String, List<int>>{};
  final _upgrading = <String>{};
  List<Note> _ownNotes = const [];

  void clearCaches() {
    _decrypted.clear();
    _noteKeys.clear();
    _pinKeks.clear();
    _publicKeys.clear();
    _upgrading.clear();
    _ownNotes = const [];
  }

  CollectionReference<Map<String, dynamic>> _notesCollection(String uid) {
    return firestore.collection('users').doc(uid).collection('notes');
  }

  DocumentReference<Map<String, dynamic>> _noteRef(String uid, String noteId) =>
      _notesCollection(uid).doc(noteId);

  // ===================================================================== keys

  /// The current key for one of the user's own notes, or null if the note is
  /// PIN-locked and not unlocked in this session.
  Future<SecretKey?> _ownNoteKey(Note note) async {
    final cached = _noteKeys[note.id];
    if (cached != null && cached.gen == note.keyGen) return cached.key;
    final wrapped = note.wrappedKey;
    if (wrapped == null) return null;
    final key = await keyManager.unwrapNoteKey(wrapped);
    _noteKeys[note.id] = (gen: note.keyGen, key: key);
    return key;
  }

  Future<SecretKey> _requireOwnNoteKey(Note note) async {
    final key = await _ownNoteKey(note);
    if (key == null) throw const NoteException('Unlock this note first.');
    return key;
  }

  /// Current key for [noteId] owned by [uid] (used when sharing).
  Future<SecretKey> ownNoteKey(String uid, String noteId) async {
    final snap = await _noteRef(uid, noteId).get();
    return _requireOwnNoteKey(Note.fromFirestore(snap));
  }

  Future<List<int>?> publicKeyOf(String uid) async {
    final cached = _publicKeys[uid];
    if (cached != null) return cached;
    final doc = await firestore.collection('users').doc(uid).get();
    final b64 = doc.data()?['publicKey'] as String?;
    if (b64 == null) return null;
    return _publicKeys[uid] = base64Decode(b64);
  }

  /// Current key for any note the viewer can read (own or shared).
  Future<SecretKey> noteKeyFor(Note note, String viewerUid) async {
    final owner = note.ownerUid ?? viewerUid;
    if (owner == viewerUid) return _requireOwnNoteKey(note);

    final cached = _noteKeys[note.id];
    if (cached != null && cached.gen == note.keyGen) return cached.key;
    final wrapped = note.encryptedKeys?[viewerUid];
    final ownerKey = await publicKeyOf(owner);
    if (wrapped == null || ownerKey == null) {
      throw const NoteException('This note has not been shared with you yet.');
    }
    final key = await keyManager.unwrapCollaboratorNoteKey(
      encryptedKeyStr: wrapped,
      ownerPublicKey: ownerKey,
    );
    _noteKeys[note.id] = (gen: note.keyGen, key: key);
    return key;
  }

  static String _historyAad(String noteId, int gen) => 'notely:keyhistory:$noteId:$gen';

  /// Every key generation of a note the viewer can read, keyed by generation.
  Future<Map<int, SecretKey>> _keyring(Note note, SecretKey current) async {
    final ring = <int, SecretKey>{note.keyGen: current};
    for (final entry in (note.keyHistory ?? const <String, String>{}).entries) {
      final gen = int.tryParse(entry.key);
      if (gen == null) continue;
      try {
        ring[gen] = await keyManager.unwrapKeyWith(
          wrappingKey: current,
          wrapped: entry.value,
          aad: _historyAad(note.id, gen),
        );
      } catch (error, stack) {
        AppErrorHandler().handle(error, stack);
      }
    }
    return ring;
  }

  // ================================================================== reading

  String _fingerprint(Map<String, dynamic> data) => [
        data[NoteFields.encryptionVersion],
        data[NoteFields.keyGen],
        data[NoteFields.encryptedTitle],
        data[NoteFields.encryptedContent],
        data[NoteFields.encryptedMeta],
        data[NoteFields.wrappedKey]?.toString(),
        data[NoteFields.pinWrappedKey],
        data[NoteFields.updatedAt]?.toString(),
        data[NoteFields.isPinned],
        data[NoteFields.isArchived],
        data[NoteFields.isLocked],
        data[NoteFields.colorIndex],
        data[NoteFields.selfDestructAt]?.toString(),
        data[NoteFields.selfDestructOnRead],
        data[NoteFields.isStudyMaterial],
        data[NoteFields.studyDueAt]?.toString(),
        data[NoteFields.collaborators]?.toString(),
        data[NoteFields.encryptedKeys]?.toString(),
        data[NoteFields.keyHistory]?.toString(),
      ].join('|');

  /// Decrypt with a per-document cache so unchanged notes are not
  /// re-decrypted on every snapshot.
  Future<Note> _decryptCached(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Future<Note> Function(Note sealed) decrypt,
  ) async {
    final data = doc.data() ?? const <String, dynamic>{};
    final fingerprint = _fingerprint(data);
    final cacheKey = doc.reference.path;
    final cached = _decrypted[cacheKey];
    if (cached != null && cached.fingerprint == fingerprint) return cached.note;
    final note = await decrypt(Note.fromFirestore(doc));
    _decrypted[cacheKey] = (fingerprint: fingerprint, note: note);
    return note;
  }

  Future<Note> _decryptOwn(String uid, Note note) async {
    if (note.encryptionVersion == 0) {
      _scheduleUpgrade(uid, note, null);
      return note;
    }
    try {
      final key = await _ownNoteKey(note);
      if (key == null) return note; // PIN-locked; stays sealed until unlocked.
      final decrypted = await note.decryptNote(key, crypto);
      if (note.encryptionVersion < Note.currentEncryptionVersion || note.hasLegacyPlaintext) {
        _scheduleUpgrade(uid, decrypted, key);
      }
      return decrypted;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      if (note.hasLegacyPlaintext) _scrubPlaintext(uid, note);
      return note.copyWith(decryptionFailed: true);
    }
  }

  Stream<List<Note>> watchNotes(String uid) {
    return _notesCollection(uid)
        .orderBy(NoteFields.updatedAt, descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final notes = (await Future.wait(
        snapshot.docs.map((doc) => _decryptCached(doc, (n) => _decryptOwn(uid, n))),
      ))
          .where((note) => !note.isExpired)
          .toList();
      _ownNotes = notes;
      final sorted = [...notes]..sort((left, right) {
          if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;
          return right.updatedAt.compareTo(left.updatedAt);
        });
      return sorted;
    });
  }

  Stream<List<Note>> watchStudyCards(String uid) {
    return _notesCollection(uid)
        .where(NoteFields.isStudyMaterial, isEqualTo: true)
        .where(NoteFields.studyDueAt, isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .orderBy(NoteFields.studyDueAt, descending: false)
        .snapshots()
        .asyncMap((snapshot) async => (await Future.wait(
              snapshot.docs.map((doc) => _decryptCached(doc, (n) => _decryptOwn(uid, n))),
            ))
                .where((note) => !note.isExpired)
                .toList());
  }

  Stream<List<Note>> getSharedNotes(String uid) {
    return firestore
        .collectionGroup('notes')
        .where(NoteFields.collaborators, arrayContains: uid)
        .orderBy(NoteFields.updatedAt, descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final decrypted = await Future.wait(snapshot.docs.map(
        (doc) => _decryptCached(doc, (note) async {
          try {
            return await note.decryptNote(await noteKeyFor(note, uid), crypto);
          } catch (error, stack) {
            AppErrorHandler().handle(error, stack);
            return note.copyWith(decryptionFailed: true);
          }
        }),
      ));
      decrypted.removeWhere((note) => note.isExpired);
      decrypted.sort((left, right) {
        if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;
        return right.updatedAt.compareTo(left.updatedAt);
      });
      return decrypted;
    });
  }

  // ================================================ migration of stored data

  /// Re-encrypt older notes in the current format and remove plaintext
  /// copies that older app versions wrote next to the ciphertext.
  void _scheduleUpgrade(String uid, Note plain, SecretKey? key) {
    if (!_upgrading.add(plain.id)) return;
    () async {
      try {
        final ref = _noteRef(uid, plain.id);
        final updates = <String, dynamic>{};
        var noteKey = key;
        if (noteKey == null) {
          noteKey = keyManager.generateNoteKey();
          updates[NoteFields.wrappedKey] = await keyManager.wrapNoteKey(noteKey);
          updates[NoteFields.keyGen] = 1;
        }
        updates.addAll(await plain.encryptedFields(noteKey, crypto));
        for (final field in NoteFields.legacyPlaintext) {
          updates[field] = FieldValue.delete();
        }
        await ref.update(updates);
        _noteKeys[plain.id] = (gen: plain.keyGen, key: noteKey);
      } catch (error, stack) {
        AppErrorHandler().handle(error, stack);
        _upgrading.remove(plain.id);
      }
    }();
  }

  /// Remove leaked plaintext even when the note itself cannot be decrypted.
  void _scrubPlaintext(String uid, Note note) {
    if (!_upgrading.add('scrub:${note.id}')) return;
    _noteRef(uid, note.id).update({
      NoteFields.title: FieldValue.delete(),
      NoteFields.content: FieldValue.delete(),
    }).catchError(AppErrorHandler().handle);
  }

  // ==================================================================== links

  static final _linkPattern = RegExp(r'\[\[([^\]]+)\]\]');

  /// Resolve `[[Title]]` references against the user's decrypted notes.
  /// Titles are encrypted, so this cannot be a server-side query.
  List<String> resolveLinks(String content, {String? selfId}) {
    final titles = _linkPattern
        .allMatches(content)
        .map((m) => m.group(1)!.trim().toLowerCase())
        .toSet();
    if (titles.isEmpty) return const [];
    return _ownNotes
        .where((n) => n.id != selfId && titles.contains((n.title ?? '').trim().toLowerCase()))
        .map((n) => n.id)
        .toSet()
        .toList();
  }

  Future<List<Note>> getBacklinks(String uid, String noteId) async {
    return _ownNotes.where((n) => n.links?.contains(noteId) ?? false).toList();
  }

  Future<List<String>> searchTitles(String uid, String query) async {
    final q = query.trim().toLowerCase();
    return _ownNotes
        .map((n) => (n.title ?? '').trim())
        .where((t) => t.isNotEmpty && t.toLowerCase().startsWith(q))
        .toSet()
        .take(8)
        .toList();
  }

  Future<String?> resolveTitleToId(String uid, String title) async {
    final ids = resolveLinks('[[$title]]');
    return ids.isEmpty ? null : ids.first;
  }

  // ================================================================== writing

  Future<Note> createNote({
    required String uid,
    required String title,
    required String content,
    required int colorIndex,
    bool isPinned = false,
    bool isStudyMaterial = false,
    List<String> audioAttachments = const [],
    double? latitude,
    double? longitude,
    String? placeName,
    List<String> tags = const [],
    DateTime? selfDestructAt,
    bool selfDestructOnRead = false,
  }) async {
    final now = DateTime.now();
    final document = _notesCollection(uid).doc();
    final noteKey = keyManager.generateNoteKey();

    final plainNote = Note(
      id: document.id,
      ownerUid: uid,
      title: title,
      content: content,
      colorIndex: colorIndex,
      isPinned: isPinned,
      isStudyMaterial: isStudyMaterial,
      audioAttachments: audioAttachments,
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      tags: tags,
      selfDestructAt: selfDestructAt,
      selfDestructOnRead: selfDestructOnRead,
      createdAt: now,
      updatedAt: now,
      links: resolveLinks(content, selfId: document.id),
      encryptionVersion: Note.currentEncryptionVersion,
    );

    await document.set({
      ...plainNote.plainFields(),
      ...await plainNote.encryptedFields(noteKey, crypto),
      NoteFields.wrappedKey: await keyManager.wrapNoteKey(noteKey),
      NoteFields.keyGen: 1,
      NoteFields.versionCounter: 0,
    });
    _noteKeys[document.id] = (gen: 1, key: noteKey);
    return plainNote;
  }

  Map<String, dynamic> _versionData(Map<String, dynamic> current, int number, DateTime now) => {
        'versionNumber': number,
        'createdAt': Timestamp.fromDate(now),
        NoteFields.encryptionVersion: current[NoteFields.encryptionVersion] ?? 0,
        NoteFields.keyGen: current[NoteFields.keyGen] ?? 1,
        NoteFields.encryptedTitle: current[NoteFields.encryptedTitle],
        NoteFields.encryptedContent: current[NoteFields.encryptedContent],
        NoteFields.encryptedMeta: current[NoteFields.encryptedMeta],
      };

  /// Save the note body and editable fields. Writes only the fields the
  /// editor owns — never collaborators, keys, or lock state — and snapshots
  /// the previous body into version history in the same transaction.
  Future<void> updateNote({
    required String uid,
    required Note note,
    bool forceVersion = false,
  }) async {
    final ref = _noteRef(uid, note.id);
    final versionsRef = ref.collection('versions');
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw const NoteException('This note no longer exists.');
      final existing = Note.fromFirestore(snap);
      final now = DateTime.now();
      final updates = <String, dynamic>{};

      var key = await _ownNoteKey(existing);
      if (key == null) {
        if (existing.hasPinLock) throw const NoteException('Unlock this note first.');
        key = keyManager.generateNoteKey();
        updates[NoteFields.wrappedKey] = await keyManager.wrapNoteKey(key);
        updates[NoteFields.keyGen] = 1;
        _noteKeys[note.id] = (gen: 1, key: key);
      }

      final lastVersionAt = (data[NoteFields.lastVersionAt] as Timestamp?)?.toDate();
      final dueForVersion = lastVersionAt == null || now.difference(lastVersionAt) >= versionInterval;
      if (existing.isSealed && (forceVersion || dueForVersion)) {
        final number = ((data[NoteFields.versionCounter] as num?)?.toInt() ?? 0) + 1;
        tx.set(versionsRef.doc(), _versionData(data, number, now));
        updates[NoteFields.versionCounter] = number;
        updates[NoteFields.lastVersionAt] = Timestamp.fromDate(now);
      }

      final plain = note.copyWith(
        updatedAt: now,
        createdAt: existing.createdAt,
        links: resolveLinks(note.content ?? '', selfId: note.id),
      );
      updates
        ..addAll(plain.plainFields())
        ..addAll(await plain.encryptedFields(key, crypto));
      for (final field in NoteFields.legacyPlaintext) {
        updates[field] = FieldValue.delete();
      }
      tx.update(ref, updates);
    });
    await _pruneVersions(uid, note.id);
  }

  Future<void> _pruneVersions(String uid, String noteId) async {
    try {
      final versions = await _noteRef(uid, noteId)
          .collection('versions')
          .orderBy('createdAt', descending: true)
          .get();
      if (versions.docs.length <= maxVersions) return;
      final batch = firestore.batch();
      for (final doc in versions.docs.skip(maxVersions)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
    }
  }

  Future<List<NoteVersion>> getVersions(String uid, String noteId) async {
    final noteSnap = await _noteRef(uid, noteId).get();
    final note = Note.fromFirestore(noteSnap);
    final ring = await _keyring(note, await _requireOwnNoteKey(note));
    final snapshot = await _noteRef(uid, noteId)
        .collection('versions')
        .orderBy('createdAt', descending: true)
        .get();
    return Future.wait(snapshot.docs.map((doc) async {
      final data = doc.data();
      final number = (data['versionNumber'] as num?)?.toInt() ?? 0;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      try {
        final sealed = Note.fromData(noteId, data);
        final key = ring[sealed.keyGen];
        if (sealed.encryptionVersion == 0) {
          return NoteVersion(id: doc.id, versionNumber: number, createdAt: createdAt,
              title: data['title'] as String?, content: data['content'] as String?);
        }
        if (key == null) throw const NoteException('Missing key for version');
        final plain = await sealed.decryptNote(key, crypto);
        return NoteVersion(id: doc.id, versionNumber: number, createdAt: createdAt,
            title: plain.title, content: plain.content);
      } catch (error, stack) {
        AppErrorHandler().handle(error, stack);
        return NoteVersion(id: doc.id, versionNumber: number, createdAt: createdAt, decryptionFailed: true);
      }
    }));
  }

  /// Restore a version. The current body is snapshotted first, so a restore
  /// can itself be undone from history.
  Future<void> restoreVersion(String uid, String noteId, String versionId) async {
    final versions = await getVersions(uid, noteId);
    final version = versions.where((v) => v.id == versionId).firstOrNull;
    if (version == null || version.decryptionFailed) {
      throw const NoteException("This version can't be restored.");
    }
    final current = await _decryptOwn(uid, Note.fromFirestore(await _noteRef(uid, noteId).get()));
    if (current.decryptionFailed || current.isSealed) {
      throw const NoteException('Unlock this note first.');
    }
    await updateNote(
      uid: uid,
      note: current.copyWith(title: version.title ?? '', content: version.content ?? ''),
      forceVersion: true,
    );
  }

  // ================================================================ deletion

  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < 400) return;
    }
  }

  Future<void> deleteNoteVersions(String uid, String noteId) =>
      _deleteAll(_noteRef(uid, noteId).collection('versions'));

  /// Delete a note with its versions, comments, and share links.
  Future<void> deleteNote({required String uid, required String noteId}) async {
    final ref = _noteRef(uid, noteId);
    await _deleteAll(ref.collection('versions'));
    await _deleteAll(ref.collection('comments'));
    final links = await firestore
        .collection('shareLinks')
        .where('ownerUid', isEqualTo: uid)
        .where('noteId', isEqualTo: noteId)
        .get();
    for (final link in links.docs) {
      await _deleteAll(link.reference.collection('requests'));
      await link.reference.delete();
    }
    await ref.delete();
    _noteKeys.remove(noteId);
    _pinKeks.remove(noteId);
    _decrypted.remove(ref.path);
  }

  Future<void> deleteExpiredNotes(String uid) async {
    final snapshot = await _notesCollection(uid)
        .where(NoteFields.selfDestructAt, isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .get();
    for (final doc in snapshot.docs) {
      await deleteNote(uid: uid, noteId: doc.id);
    }
  }

  Future<void> deleteMany({required String uid, required List<Note> notes}) async {
    await Future.wait(notes.map((note) => deleteNote(uid: uid, noteId: note.id)));
  }

  // ======================================================= simple field edits
  // These deliberately do not touch updatedAt: pinning or archiving a note is
  // not an edit and should not reorder the list or mark it as changed.

  Future<void> updateStudyProgress({
    required String uid,
    required String noteId,
    required int studyInterval,
    required double studyEaseFactor,
    required int studyRepetitions,
    required DateTime studyDueAt,
  }) async {
    await _noteRef(uid, noteId).update({
      NoteFields.studyInterval: studyInterval,
      NoteFields.studyEaseFactor: studyEaseFactor,
      NoteFields.studyRepetitions: studyRepetitions,
      NoteFields.studyDueAt: Timestamp.fromDate(studyDueAt),
    });
  }

  Future<void> togglePin({required String uid, required Note note}) async {
    await _noteRef(uid, note.id).update({NoteFields.isPinned: !note.isPinned});
  }

  Future<void> setArchived({required String uid, required Note note, required bool archived}) async {
    await _noteRef(uid, note.id).update({NoteFields.isArchived: archived});
  }

  Future<void> archiveMany({required String uid, required List<Note> notes}) async {
    final batch = firestore.batch();
    for (final note in notes) {
      batch.update(_noteRef(uid, note.id), {NoteFields.isArchived: true});
    }
    await batch.commit();
  }

  Future<void> setPinnedMany({required String uid, required List<Note> notes, required bool pinned}) async {
    final batch = firestore.batch();
    for (final note in notes) {
      batch.update(_noteRef(uid, note.id), {NoteFields.isPinned: pinned});
    }
    await batch.commit();
  }

  // ==================================================================== locks
  //
  // PIN locks are cryptographic: the note key is wrapped with a key derived
  // from the PIN *and* the master key, and the master-key wrapping is removed.
  // The server holds no PIN verifier, so the PIN cannot be brute-forced from
  // Firestore data, and the note cannot be decrypted without the PIN.
  //
  // Biometric unlock is a convenience on top of a PIN lock: the PIN-derived
  // key is kept in biometric-protected device storage (BiometricUnlockService)
  // and handed back here via [unlockWithKek]. Older biometric-only locks are
  // a privacy screen until the user sets a PIN.

  Future<SecretKey> _pinKek(String noteId, String pin, List<int> salt) async {
    final stretched = await crypto.deriveKey(password: pin, salt: salt, iterations: _pinIterations);
    final master = await keyManager.requireMasterKey();
    return crypto.hkdf(
      secret: [...await master.extractBytes(), ...await stretched.extractBytes()],
      salt: salt,
      info: 'notely-pin-lock-v1:$noteId',
    );
  }

  static String _pinAad(String noteId) => 'notely:pin:$noteId';

  Future<void> lockWithPin({required String uid, required Note note, required String pin}) async {
    final ref = _noteRef(uid, note.id);
    final existing = Note.fromFirestore(await ref.get());
    final key = await _requireOwnNoteKey(existing);
    final salt = crypto.generateSalt();
    final kek = await _pinKek(note.id, pin, salt);
    await ref.update({
      NoteFields.isLocked: true,
      NoteFields.pinWrappedKey: await keyManager.wrapKeyWith(wrappingKey: kek, key: key, aad: _pinAad(note.id)),
      NoteFields.pinSalt: base64Encode(salt),
      NoteFields.wrappedKey: FieldValue.delete(),
      NoteFields.pinHash: FieldValue.delete(),
    });
    _pinKeks[note.id] = kek;
    _noteKeys[note.id] = (gen: existing.keyGen, key: key);
  }

  /// Raw bytes of the PIN-derived key for a note unlocked in this session,
  /// for storing behind biometrics. Null if the note is not unlocked.
  Future<List<int>?> exportPinKek(String noteId) async {
    final kek = _pinKeks[noteId];
    return kek?.extractBytes();
  }

  /// Unlock a PIN-locked note with a previously exported PIN-derived key.
  /// Returns null if the key no longer matches (e.g. the PIN was changed).
  Future<Note?> unlockWithKek({required Note note, required List<int> kek}) async {
    final wrapped = note.pinWrappedKey;
    if (wrapped == null) return null;
    final kekKey = SecretKey(List<int>.from(kek));
    try {
      final key = await keyManager.unwrapKeyWith(
        wrappingKey: kekKey,
        wrapped: wrapped,
        aad: _pinAad(note.id),
      );
      _pinKeks[note.id] = kekKey;
      _noteKeys[note.id] = (gen: note.keyGen, key: key);
      return note.isSealed ? note.decryptNote(key, crypto) : note;
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  /// Returns the decrypted note, or null if [pin] is wrong.
  Future<Note?> unlockWithPin({required String uid, required Note note, required String pin}) async {
    final salt = note.pinSalt;
    if (salt == null) return null;

    if (note.pinWrappedKey != null) {
      try {
        final kek = await _pinKek(note.id, pin, base64Decode(salt));
        final key = await keyManager.unwrapKeyWith(
          wrappingKey: kek,
          wrapped: note.pinWrappedKey!,
          aad: _pinAad(note.id),
        );
        _pinKeks[note.id] = kek;
        _noteKeys[note.id] = (gen: note.keyGen, key: key);
        return note.isSealed ? note.decryptNote(key, crypto) : note;
      } on SecretBoxAuthenticationError {
        return null;
      }
    }

    // Legacy lock: a PBKDF2 PIN hash stored on the note. Verify, then
    // upgrade to a cryptographic lock with the same PIN.
    if (note.pinHash == null) return null;
    final derived = await crypto.deriveKey(
      password: pin,
      salt: base64Decode(salt),
      iterations: _legacyPinIterations,
    );
    final ok = _constantTimeEquals(await derived.extractBytes(), base64Decode(note.pinHash!));
    if (!ok) return null;
    try {
      await lockWithPin(uid: uid, note: note, pin: pin);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
    }
    final key = await _ownNoteKey(note);
    return key == null || !note.isSealed ? note : note.decryptNote(key, crypto);
  }

  Future<void> removeLock({required String uid, required Note note}) async {
    final updates = <String, dynamic>{
      NoteFields.isLocked: false,
      NoteFields.pinHash: FieldValue.delete(),
      NoteFields.pinSalt: FieldValue.delete(),
      NoteFields.pinWrappedKey: FieldValue.delete(),
    };
    if (note.pinWrappedKey != null) {
      final cached = _noteKeys[note.id];
      if (cached == null) throw const NoteException('Unlock this note first.');
      updates[NoteFields.wrappedKey] = await keyManager.wrapNoteKey(cached.key);
    }
    await _noteRef(uid, note.id).update(updates);
    _pinKeks.remove(note.id);
  }

  /// Forget an unlocked PIN note's key (editor closed / app backgrounded).
  void relock(String noteId) {
    if (_pinKeks.remove(noteId) != null) {
      _noteKeys.remove(noteId);
      _decrypted.removeWhere((path, _) => path.endsWith('/notes/$noteId'));
    }
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // ============================================================ key rotation

  /// Replace a note's key, re-encrypting its body and re-wrapping it for
  /// [collaborators]. Old keys are kept (sealed under the new key) so earlier
  /// comments and versions stay readable to those who still have access.
  /// Used when a collaborator is removed, so they cannot read future edits.
  Future<void> rotateNoteKey({
    required String uid,
    required String noteId,
    required List<String> collaborators,
  }) async {
    final publicKeys = <String, List<int>>{};
    for (final collaborator in collaborators) {
      final key = await publicKeyOf(collaborator);
      if (key != null) publicKeys[collaborator] = key;
    }

    final ref = _noteRef(uid, noteId);
    late SecretKey newKey;
    late int newGen;
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final sealed = Note.fromFirestore(snap);
      final oldKey = await _requireOwnNoteKey(sealed);
      final ring = await _keyring(sealed, oldKey);
      final plain = await sealed.decryptNote(oldKey, crypto);

      newKey = keyManager.generateNoteKey();
      newGen = sealed.keyGen + 1;
      final history = <String, String>{};
      for (final entry in ring.entries) {
        history['${entry.key}'] = await keyManager.wrapKeyWith(
          wrappingKey: newKey,
          key: entry.value,
          aad: _historyAad(noteId, entry.key),
        );
      }

      final encryptedKeys = <String, String>{};
      for (final entry in publicKeys.entries) {
        encryptedKeys[entry.key] = await keyManager.wrapNoteKeyForCollaborator(
          noteKey: newKey,
          recipientPublicKey: entry.value,
        );
      }

      final updates = <String, dynamic>{
        ...await plain.encryptedFields(newKey, crypto),
        NoteFields.keyGen: newGen,
        NoteFields.keyHistory: history,
        NoteFields.collaborators: publicKeys.keys.toList(),
        NoteFields.encryptedKeys: encryptedKeys,
      };
      final kek = _pinKeks[noteId];
      if (sealed.pinWrappedKey != null) {
        if (kek == null) throw const NoteException('Unlock this note first.');
        updates[NoteFields.pinWrappedKey] =
            await keyManager.wrapKeyWith(wrappingKey: kek, key: newKey, aad: _pinAad(noteId));
      } else {
        updates[NoteFields.wrappedKey] = await keyManager.wrapNoteKey(newKey);
      }
      if (publicKeys.isEmpty) {
        updates[NoteFields.sharedBy] = FieldValue.delete();
        updates[NoteFields.sharedAt] = FieldValue.delete();
      }
      tx.update(ref, updates);
    });
    _noteKeys[noteId] = (gen: newGen, key: newKey);
  }

  // ================================================================ comments

  CollectionReference<Map<String, dynamic>> _commentsCollection(String noteOwnerId, String noteId) {
    return _noteRef(noteOwnerId, noteId).collection('comments');
  }

  Future<void> addComment({
    required String noteOwnerId,
    required String noteId,
    required String authorUid,
    required String authorName,
    required String content,
  }) async {
    final note = Note.fromFirestore(await _noteRef(noteOwnerId, noteId).get());
    final key = await noteKeyFor(note, authorUid);
    final doc = _commentsCollection(noteOwnerId, noteId).doc();
    await doc.set(await Comment.encryptedMap(
      noteId: noteId,
      commentId: doc.id,
      authorUid: authorUid,
      authorName: authorName,
      content: content,
      noteKey: key,
      keyGen: note.keyGen,
      crypto: crypto,
    ));
  }

  Stream<List<Comment>> watchComments(String noteOwnerId, String noteId, String viewerUid) {
    return _commentsCollection(noteOwnerId, noteId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final comments = snapshot.docs.map(Comment.fromFirestore).toList();
      if (comments.every((c) => c.encryptedContent == null)) return comments;
      Map<int, SecretKey> ring = const {};
      try {
        final note = Note.fromFirestore(await _noteRef(noteOwnerId, noteId).get());
        ring = await _keyring(note, await noteKeyFor(note, viewerUid));
      } catch (error, stack) {
        AppErrorHandler().handle(error, stack);
      }
      return Future.wait(comments.map((comment) async {
        final key = ring[comment.keyGen];
        if (comment.encryptedContent == null) return comment;
        if (key == null) return comment.asUndecryptable();
        try {
          return await comment.decrypt(noteId, key, crypto);
        } catch (_) {
          return comment.asUndecryptable();
        }
      }));
    });
  }

  Future<void> deleteComment({
    required String noteOwnerId,
    required String noteId,
    required String commentId,
    required String authorUid,
  }) async {
    final doc = _commentsCollection(noteOwnerId, noteId).doc(commentId);
    final snapshot = await doc.get();
    final data = snapshot.data() ?? {};
    if (data['authorUid'] != authorUid && noteOwnerId != authorUid) {
      throw const NoteException('Only the author can delete this comment.');
    }
    await doc.delete();
  }

  Future<void> reportComment({
    required String noteOwnerId,
    required String noteId,
    required String commentId,
    required String commentAuthorUid,
    required String reporterUid,
    required String reason,
  }) async {
    final doc = firestore.collection('reports').doc();
    await doc.set(ContentReport.create(
      targetOwnerUid: noteOwnerId,
      noteId: noteId,
      commentId: commentId,
      commentAuthorUid: commentAuthorUid,
      reporterUid: reporterUid,
      reason: reason,
    ).toMap());
  }
}
