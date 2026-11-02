import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';

/// Firestore field names for note documents, in one place.
abstract final class NoteFields {
  static const title = 'title';
  static const content = 'content';
  static const encryptedTitle = 'encryptedTitle';
  static const encryptedContent = 'encryptedContent';
  static const encryptedMeta = 'encryptedMeta';
  static const encryptionVersion = 'encryptionVersion';
  static const wrappedKey = 'wrappedKey';
  static const pinWrappedKey = 'pinWrappedKey';
  static const keyGen = 'keyGen';
  static const keyHistory = 'keyHistory';
  static const colorIndex = 'colorIndex';
  static const isPinned = 'isPinned';
  static const isArchived = 'isArchived';
  static const isLocked = 'isLocked';
  static const pinHash = 'pinHash';
  static const pinSalt = 'pinSalt';
  static const selfDestructAt = 'selfDestructAt';
  static const selfDestructOnRead = 'selfDestructOnRead';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
  static const audioAttachments = 'audioAttachments';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const placeName = 'placeName';
  static const links = 'links';
  static const tags = 'tags';
  static const isStudyMaterial = 'isStudyMaterial';
  static const studyDueAt = 'studyDueAt';
  static const studyInterval = 'studyInterval';
  static const studyEaseFactor = 'studyEaseFactor';
  static const studyRepetitions = 'studyRepetitions';
  static const collaborators = 'collaborators';
  static const encryptedKeys = 'encryptedKeys';
  static const sharedBy = 'sharedBy';
  static const sharedAt = 'sharedAt';
  static const versionCounter = 'versionCounter';
  static const lastVersionAt = 'lastVersionAt';

  /// Fields that must never be stored in plaintext on an encrypted note.
  /// Older app versions wrote these alongside the ciphertext.
  static const legacyPlaintext = [
    title, content, tags, latitude, longitude, placeName, audioAttachments, links,
  ];
}

class Note {
  static const _ignore = Object();

  /// Current on-disk format: AES-GCM with per-field AAD, metadata encrypted.
  static const currentEncryptionVersion = 2;

  final String id;

  /// uid of the note owner (parent document id); null for unsaved notes.
  final String? ownerUid;

  final String? title;
  final String? content;
  final String? encryptedTitle;
  final String? encryptedContent;
  final String? encryptedMeta;
  final Map<String, String>? wrappedKey;

  /// Note key wrapped with a PIN-derived key (PIN-locked notes only).
  final String? pinWrappedKey;
  final int encryptionVersion;

  /// Generation of the current note key; bumped on every key rotation.
  final int keyGen;

  /// Older note keys (by generation) sealed under the current note key, so
  /// comments and versions written before a rotation stay readable.
  final Map<String, String>? keyHistory;
  final int colorIndex;
  final bool isPinned;
  final bool isArchived;
  final bool isLocked;

  /// Legacy (pre-v2) PIN verifier. New locks use [pinWrappedKey] instead.
  final String? pinHash;
  final String? pinSalt;
  final DateTime? selfDestructAt;
  final bool selfDestructOnRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> audioAttachments;
  final double? latitude;
  final double? longitude;
  final String? placeName;
  final List<String>? links;
  final bool isStudyMaterial;
  final DateTime? studyDueAt;
  final int? studyInterval;
  final double? studyEaseFactor;
  final int? studyRepetitions;
  final List<String>? collaborators;
  final Map<String, String>? encryptedKeys;
  final String? sharedBy;
  final DateTime? sharedAt;
  final List<String>? tags;

  /// True when this note is encrypted but could not be decrypted on this
  /// device (missing/wrong key). UI must not treat it as an empty note.
  final bool decryptionFailed;

  /// True when the stored document still carries plaintext copies of
  /// encrypted fields (written by older app versions) and must be scrubbed.
  final bool hasLegacyPlaintext;

  const Note({
    required this.id,
    this.ownerUid,
    this.title,
    this.content,
    this.encryptedTitle,
    this.encryptedContent,
    this.encryptedMeta,
    this.wrappedKey,
    this.pinWrappedKey,
    this.encryptionVersion = 0,
    this.keyGen = 1,
    this.keyHistory,
    required this.colorIndex,
    required this.isPinned,
    this.isArchived = false,
    this.isLocked = false,
    this.pinHash,
    this.pinSalt,
    this.selfDestructAt,
    this.selfDestructOnRead = false,
    required this.createdAt,
    required this.updatedAt,
    this.audioAttachments = const [],
    this.latitude,
    this.longitude,
    this.placeName,
    this.links,
    this.isStudyMaterial = false,
    this.studyDueAt,
    this.studyInterval,
    this.studyEaseFactor,
    this.studyRepetitions,
    this.collaborators,
    this.encryptedKeys,
    this.sharedBy,
    this.sharedAt,
    this.tags,
    this.decryptionFailed = false,
    this.hasLegacyPlaintext = false,
  });

  /// Whether the note body is still ciphertext (not yet decrypted).
  bool get isSealed => encryptionVersion >= 1 && (encryptedTitle != null || encryptedContent != null);

  /// PIN-locked notes need the PIN to unwrap their key.
  bool get hasPinLock => pinWrappedKey != null || pinHash != null;

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Note.fromData(doc.id, doc.data() ?? const {}, ownerUid: doc.reference.parent.parent?.id);
  }

  factory Note.fromData(String id, Map<String, dynamic> data, {String? ownerUid}) {
    final encryptionVersion = (data[NoteFields.encryptionVersion] as num?)?.toInt() ?? 0;
    final encrypted = encryptionVersion >= 1;
    final legacyPlaintext = encrypted &&
        ((data[NoteFields.title] as String? ?? '').isNotEmpty ||
            (data[NoteFields.content] as String? ?? '').isNotEmpty ||
            (encryptionVersion >= 2 &&
                NoteFields.legacyPlaintext.any((f) => data[f] != null)));

    // v0 notes and v1 notes keep their metadata in plaintext fields; v2
    // notes keep it inside encryptedMeta.
    final plainMeta = encryptionVersion < 2;

    return Note(
      id: id,
      ownerUid: ownerUid,
      title: encrypted ? null : (data[NoteFields.title] as String? ?? '').trim(),
      content: encrypted ? null : (data[NoteFields.content] as String? ?? '').trim(),
      encryptedTitle: data[NoteFields.encryptedTitle] as String?,
      encryptedContent: data[NoteFields.encryptedContent] as String?,
      encryptedMeta: data[NoteFields.encryptedMeta] as String?,
      wrappedKey: _stringMap(data[NoteFields.wrappedKey]),
      pinWrappedKey: data[NoteFields.pinWrappedKey] as String?,
      encryptionVersion: encryptionVersion,
      keyGen: (data[NoteFields.keyGen] as num?)?.toInt() ?? 1,
      keyHistory: _stringMap(data[NoteFields.keyHistory]),
      colorIndex: (data[NoteFields.colorIndex] as num?)?.toInt() ?? 0,
      isPinned: (data[NoteFields.isPinned] as bool?) ?? false,
      isArchived: (data[NoteFields.isArchived] as bool?) ?? false,
      isLocked: (data[NoteFields.isLocked] as bool?) ?? false,
      pinHash: data[NoteFields.pinHash] as String?,
      pinSalt: data[NoteFields.pinSalt] as String?,
      selfDestructAt: _toDateTime(data[NoteFields.selfDestructAt]),
      selfDestructOnRead: (data[NoteFields.selfDestructOnRead] as bool?) ?? false,
      createdAt: _toDateTime(data[NoteFields.createdAt]) ?? DateTime.now(),
      updatedAt: _toDateTime(data[NoteFields.updatedAt]) ?? DateTime.now(),
      audioAttachments: plainMeta ? _stringList(data[NoteFields.audioAttachments]) ?? const [] : const [],
      latitude: plainMeta ? (data[NoteFields.latitude] as num?)?.toDouble() : null,
      longitude: plainMeta ? (data[NoteFields.longitude] as num?)?.toDouble() : null,
      placeName: plainMeta ? data[NoteFields.placeName] as String? : null,
      links: plainMeta ? _stringList(data[NoteFields.links]) : null,
      tags: plainMeta ? _stringList(data[NoteFields.tags]) : null,
      isStudyMaterial: (data[NoteFields.isStudyMaterial] as bool?) ?? false,
      studyDueAt: _toDateTime(data[NoteFields.studyDueAt]),
      studyInterval: (data[NoteFields.studyInterval] as num?)?.toInt(),
      studyEaseFactor: (data[NoteFields.studyEaseFactor] as num?)?.toDouble(),
      studyRepetitions: (data[NoteFields.studyRepetitions] as num?)?.toInt(),
      collaborators: _stringList(data[NoteFields.collaborators]),
      encryptedKeys: _stringMap(data[NoteFields.encryptedKeys]),
      sharedBy: data[NoteFields.sharedBy] as String?,
      sharedAt: _toDateTime(data[NoteFields.sharedAt]),
      hasLegacyPlaintext: legacyPlaintext,
    );
  }

  static List<String>? _stringList(Object? value) =>
      value is List ? value.map((e) => e.toString()).toList() : null;

  static Map<String, String>? _stringMap(Object? value) =>
      value is Map ? value.map((k, v) => MapEntry(k.toString(), v.toString())) : null;

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Note copyWith({
    Object? title = _ignore,
    Object? content = _ignore,
    Object? encryptedTitle = _ignore,
    Object? encryptedContent = _ignore,
    Object? encryptedMeta = _ignore,
    Object? wrappedKey = _ignore,
    Object? pinWrappedKey = _ignore,
    int? encryptionVersion,
    int? keyGen,
    Object? keyHistory = _ignore,
    int? colorIndex,
    bool? isPinned,
    bool? isArchived,
    bool? isLocked,
    Object? pinHash = _ignore,
    Object? pinSalt = _ignore,
    Object? selfDestructAt = _ignore,
    bool? selfDestructOnRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? audioAttachments,
    Object? latitude = _ignore,
    Object? longitude = _ignore,
    Object? placeName = _ignore,
    Object? links = _ignore,
    bool? isStudyMaterial,
    Object? studyDueAt = _ignore,
    Object? studyInterval = _ignore,
    Object? studyEaseFactor = _ignore,
    Object? studyRepetitions = _ignore,
    Object? collaborators = _ignore,
    Object? encryptedKeys = _ignore,
    Object? sharedBy = _ignore,
    Object? sharedAt = _ignore,
    Object? tags = _ignore,
    bool? decryptionFailed,
    bool? hasLegacyPlaintext,
  }) {
    T? pick<T>(Object? value, T? current) => identical(value, _ignore) ? current : value as T?;
    return Note(
      id: id,
      ownerUid: ownerUid,
      title: pick(title, this.title),
      content: pick(content, this.content),
      encryptedTitle: pick(encryptedTitle, this.encryptedTitle),
      encryptedContent: pick(encryptedContent, this.encryptedContent),
      encryptedMeta: pick(encryptedMeta, this.encryptedMeta),
      wrappedKey: pick(wrappedKey, this.wrappedKey),
      pinWrappedKey: pick(pinWrappedKey, this.pinWrappedKey),
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      keyGen: keyGen ?? this.keyGen,
      keyHistory: pick(keyHistory, this.keyHistory),
      colorIndex: colorIndex ?? this.colorIndex,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isLocked: isLocked ?? this.isLocked,
      pinHash: pick(pinHash, this.pinHash),
      pinSalt: pick(pinSalt, this.pinSalt),
      selfDestructAt: pick(selfDestructAt, this.selfDestructAt),
      selfDestructOnRead: selfDestructOnRead ?? this.selfDestructOnRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioAttachments: audioAttachments ?? this.audioAttachments,
      latitude: pick(latitude, this.latitude),
      longitude: pick(longitude, this.longitude),
      placeName: pick(placeName, this.placeName),
      links: pick(links, this.links),
      isStudyMaterial: isStudyMaterial ?? this.isStudyMaterial,
      studyDueAt: pick(studyDueAt, this.studyDueAt),
      studyInterval: pick(studyInterval, this.studyInterval),
      studyEaseFactor: pick(studyEaseFactor, this.studyEaseFactor),
      studyRepetitions: pick(studyRepetitions, this.studyRepetitions),
      collaborators: pick(collaborators, this.collaborators),
      encryptedKeys: pick(encryptedKeys, this.encryptedKeys),
      sharedBy: pick(sharedBy, this.sharedBy),
      sharedAt: pick(sharedAt, this.sharedAt),
      tags: pick(tags, this.tags),
      decryptionFailed: decryptionFailed ?? this.decryptionFailed,
      hasLegacyPlaintext: hasLegacyPlaintext ?? this.hasLegacyPlaintext,
    );
  }

  // ------------------------------------------------------------ persistence

  /// Non-secret fields that the owner edits. Deliberately excludes the note
  /// body, metadata, keys, lock state, and sharing fields — each of those is
  /// written only by the operation that owns it, so a stale editor copy can
  /// never overwrite them.
  Map<String, dynamic> plainFields() {
    return {
      NoteFields.colorIndex: colorIndex,
      NoteFields.isPinned: isPinned,
      NoteFields.isArchived: isArchived,
      NoteFields.isStudyMaterial: isStudyMaterial,
      NoteFields.selfDestructAt: selfDestructAt != null ? Timestamp.fromDate(selfDestructAt!) : null,
      NoteFields.selfDestructOnRead: selfDestructOnRead,
      NoteFields.createdAt: Timestamp.fromDate(createdAt),
      NoteFields.updatedAt: Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> _metaJson() => {
        NoteFields.tags: tags ?? const <String>[],
        NoteFields.latitude: latitude,
        NoteFields.longitude: longitude,
        NoteFields.placeName: placeName,
        NoteFields.audioAttachments: audioAttachments,
        NoteFields.links: links ?? const <String>[],
      };

  static String aad(String noteId, String field) => 'notely:v2:$noteId:$field';

  /// Encrypt title, content, and metadata with [noteKey] (current format).
  /// Returns the Firestore fields to write.
  Future<Map<String, dynamic>> encryptedFields(SecretKey noteKey, CryptoService crypto) async {
    Future<String> seal(String field, String value) =>
        crypto.seal(key: noteKey, data: utf8.encode(value), aad: aad(id, field));
    return {
      NoteFields.encryptedTitle: await seal(NoteFields.title, title ?? ''),
      NoteFields.encryptedContent: await seal(NoteFields.content, content ?? ''),
      NoteFields.encryptedMeta: await seal('meta', jsonEncode(_metaJson())),
      NoteFields.encryptionVersion: currentEncryptionVersion,
    };
  }

  /// Encrypt into a sealed copy of this note (no plaintext retained).
  Future<Note> encryptNote(SecretKey noteKey, CryptoService crypto) async {
    final fields = await encryptedFields(noteKey, crypto);
    return copyWith(
      title: null,
      content: null,
      tags: null,
      latitude: null,
      longitude: null,
      placeName: null,
      links: null,
      audioAttachments: const [],
      encryptedTitle: fields[NoteFields.encryptedTitle],
      encryptedContent: fields[NoteFields.encryptedContent],
      encryptedMeta: fields[NoteFields.encryptedMeta],
      encryptionVersion: currentEncryptionVersion,
    );
  }

  /// Decrypt a sealed note. Supports v1 (no AAD, plaintext metadata) and v2.
  Future<Note> decryptNote(SecretKey noteKey, CryptoService crypto) async {
    if (encryptionVersion == 0 || !isSealed) return this;

    if (encryptionVersion == 1) {
      Future<String> open(String? value) async => value == null
          ? ''
          : crypto.decrypt(key: noteKey, payload: EncryptedPayload.fromBase64(value));
      return copyWith(
        title: await open(encryptedTitle),
        content: await open(encryptedContent),
        encryptedTitle: null,
        encryptedContent: null,
      );
    }

    Future<String> open(String field, String? value) async => value == null
        ? ''
        : utf8.decode(await crypto.open(key: noteKey, sealed: value, aad: aad(id, field)));

    final title = await open(NoteFields.title, encryptedTitle);
    final content = await open(NoteFields.content, encryptedContent);
    final metaRaw = await open('meta', encryptedMeta);
    final meta = metaRaw.isEmpty ? const <String, dynamic>{} : jsonDecode(metaRaw) as Map<String, dynamic>;

    return copyWith(
      title: title,
      content: content,
      tags: _stringList(meta[NoteFields.tags]),
      latitude: (meta[NoteFields.latitude] as num?)?.toDouble(),
      longitude: (meta[NoteFields.longitude] as num?)?.toDouble(),
      placeName: meta[NoteFields.placeName] as String?,
      audioAttachments: _stringList(meta[NoteFields.audioAttachments]) ?? const [],
      links: _stringList(meta[NoteFields.links]),
      encryptedTitle: null,
      encryptedContent: null,
      encryptedMeta: null,
    );
  }

  String get displayTitle {
    if (decryptionFailed) return "Can't decrypt on this device";
    if (isSealed && isLocked) return 'Locked note';
    final trimmed = (title ?? '').trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    final preview = (content ?? '').trim();
    if (preview.isNotEmpty) {
      return preview.split('\n').first;
    }

    return 'Untitled note';
  }

  String get previewText {
    if (decryptionFailed) return 'This note was encrypted with a key that is not on this device.';
    if (isLocked) return 'Unlock to view.';
    final combined = (content ?? '').trim().isNotEmpty
        ? (content ?? '').trim()
        : (title ?? '').trim();
    if (combined.isEmpty) {
      return 'Start typing your note here.';
    }

    return combined.replaceAll('\n', ' ').trim();
  }
}
