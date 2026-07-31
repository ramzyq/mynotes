import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';

class Note {
  static const _ignore = Object();

  final String id;
  final String? title;
  final String? content;
  final String? encryptedTitle;
  final String? encryptedContent;
  final Map<String, String>? wrappedKey;
  final int encryptionVersion;
  final int colorIndex;
  final bool isPinned;
  final bool isLocked;
  final String? pinHash;
  final String? pinSalt;
  final DateTime? selfDestructAt;
  final bool selfDestructOnRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> audioAttachments;
  final double? latitude;
  final double? longitude;
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

  const Note({
    required this.id,
    this.title,
    this.content,
    this.encryptedTitle,
    this.encryptedContent,
    this.wrappedKey,
    this.encryptionVersion = 0,
    required this.colorIndex,
    required this.isPinned,
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
  });

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final encryptionVersion = (data['encryptionVersion'] as int?) ?? 0;

    if (encryptionVersion == 0) {
      return Note(
        id: doc.id,
        title: (data['title'] as String? ?? '').trim(),
        content: (data['content'] as String? ?? '').trim(),
        colorIndex: (data['colorIndex'] as int?) ?? 0,
        isPinned: (data['isPinned'] as bool?) ?? false,
        isLocked: (data['isLocked'] as bool?) ?? false,
        pinHash: data['pinHash'] as String?,
        pinSalt: data['pinSalt'] as String?,
        selfDestructAt: _timestampToDateTime(data['selfDestructAt']),
        selfDestructOnRead: (data['selfDestructOnRead'] as bool?) ?? false,
        audioAttachments: (data['audioAttachments'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        links: (data['links'] as List<dynamic>?)?.cast<String>(),
        createdAt: _timestampToDateTime(data['createdAt']) ?? DateTime.now(),
        updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
        isStudyMaterial: (data['isStudyMaterial'] as bool?) ?? false,
        studyDueAt: _timestampToDateTime(data['studyDueAt']),
        studyInterval: (data['studyInterval'] as int?),
        studyEaseFactor: (data['studyEaseFactor'] as num?)?.toDouble(),
        studyRepetitions: (data['studyRepetitions'] as int?),
        collaborators: (data['collaborators'] as List<dynamic>?)?.cast<String>(),
        encryptedKeys: data['encryptedKeys'] != null
            ? (data['encryptedKeys'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, v as String),
              )
            : null,
        sharedBy: data['sharedBy'] as String?,
        sharedAt: _timestampToDateTime(data['sharedAt']),
        tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
      );
    }

    Map<String, String>? wrappedKey;
    final wrappedKeyRaw = data['wrappedKey'];
    if (wrappedKeyRaw is Map) {
      wrappedKey = (wrappedKeyRaw as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      );
    }

      return Note(
        id: doc.id,
        encryptedTitle: data['encryptedTitle'] as String?,
        encryptedContent: data['encryptedContent'] as String?,
        wrappedKey: wrappedKey,
        encryptionVersion: encryptionVersion,
        colorIndex: (data['colorIndex'] as int?) ?? 0,
        isPinned: (data['isPinned'] as bool?) ?? false,
        isLocked: (data['isLocked'] as bool?) ?? false,
        pinHash: data['pinHash'] as String?,
        pinSalt: data['pinSalt'] as String?,
        selfDestructAt: _timestampToDateTime(data['selfDestructAt']),
        selfDestructOnRead: (data['selfDestructOnRead'] as bool?) ?? false,
        audioAttachments: (data['audioAttachments'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        links: (data['links'] as List<dynamic>?)?.cast<String>(),
        createdAt: _timestampToDateTime(data['createdAt']) ?? DateTime.now(),
        updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
        isStudyMaterial: (data['isStudyMaterial'] as bool?) ?? false,
        studyDueAt: _timestampToDateTime(data['studyDueAt']),
        studyInterval: (data['studyInterval'] as int?),
        studyEaseFactor: (data['studyEaseFactor'] as num?)?.toDouble(),
        studyRepetitions: (data['studyRepetitions'] as int?),
        collaborators: (data['collaborators'] as List<dynamic>?)?.cast<String>(),
        encryptedKeys: data['encryptedKeys'] != null
            ? (data['encryptedKeys'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, v as String),
              )
            : null,
        sharedBy: data['sharedBy'] as String?,
        sharedAt: _timestampToDateTime(data['sharedAt']),
        tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
      );
  }

  static DateTime? _timestampToDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  Note copyWith({
    String? title,
    String? content,
    String? encryptedTitle,
    String? encryptedContent,
    Map<String, String>? wrappedKey,
    int? encryptionVersion,
    int? colorIndex,
    bool? isPinned,
    bool? isLocked,
    String? pinHash,
    String? pinSalt,
    Object? selfDestructAt = _ignore,
    bool? selfDestructOnRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? audioAttachments,
    Object? latitude = _ignore,
    Object? longitude = _ignore,
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
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      encryptedTitle: encryptedTitle ?? this.encryptedTitle,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      wrappedKey: wrappedKey ?? this.wrappedKey,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      colorIndex: colorIndex ?? this.colorIndex,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      selfDestructAt: selfDestructAt == _ignore ? this.selfDestructAt : selfDestructAt as DateTime?,
      selfDestructOnRead: selfDestructOnRead ?? this.selfDestructOnRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioAttachments: audioAttachments ?? this.audioAttachments,
      latitude: latitude == _ignore ? this.latitude : latitude as double?,
      longitude: longitude == _ignore ? this.longitude : longitude as double?,
      links: links == _ignore ? this.links : links as List<String>?,
      isStudyMaterial: isStudyMaterial ?? this.isStudyMaterial,
      studyDueAt: studyDueAt == _ignore ? this.studyDueAt : studyDueAt as DateTime?,
      studyInterval: studyInterval == _ignore ? this.studyInterval : studyInterval as int?,
      studyEaseFactor: studyEaseFactor == _ignore ? this.studyEaseFactor : studyEaseFactor as double?,
      studyRepetitions: studyRepetitions == _ignore ? this.studyRepetitions : studyRepetitions as int?,
      collaborators: collaborators == _ignore ? this.collaborators : collaborators as List<String>?,
      encryptedKeys: encryptedKeys == _ignore ? this.encryptedKeys : encryptedKeys as Map<String, String>?,
      sharedBy: sharedBy == _ignore ? this.sharedBy : sharedBy as String?,
      sharedAt: sharedAt == _ignore ? this.sharedAt : sharedAt as DateTime?,
      tags: tags == _ignore ? this.tags : tags as List<String>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title ?? '',
      'content': content ?? '',
      'encryptedTitle': encryptedTitle,
      'encryptedContent': encryptedContent,
      'wrappedKey': wrappedKey,
      'encryptionVersion': encryptionVersion,
      'colorIndex': colorIndex,
      'isPinned': isPinned,
      'isLocked': isLocked,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'selfDestructAt': selfDestructAt != null ? Timestamp.fromDate(selfDestructAt as DateTime) : null,
      'selfDestructOnRead': selfDestructOnRead,
      'audioAttachments': audioAttachments,
      'latitude': latitude,
      'longitude': longitude,
      'links': links,
      'isStudyMaterial': isStudyMaterial,
      'studyDueAt': studyDueAt != null ? Timestamp.fromDate(studyDueAt as DateTime) : null,
      'studyInterval': studyInterval,
      'studyEaseFactor': studyEaseFactor,
      'studyRepetitions': studyRepetitions,
      'collaborators': collaborators,
      'encryptedKeys': encryptedKeys,
      'sharedBy': sharedBy,
      'sharedAt': sharedAt != null ? Timestamp.fromDate(sharedAt as DateTime) : null,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Future<Note> encryptNote(SecretKey noteKey, CryptoService crypto) async {
    final titleEnc = await crypto.encrypt(key: noteKey, plaintext: title ?? '');
    final contentEnc = await crypto.encrypt(key: noteKey, plaintext: content ?? '');
    return copyWith(
      encryptedTitle: base64Encode(titleEnc.ciphertext + titleEnc.nonce + titleEnc.mac),
      encryptedContent: base64Encode(contentEnc.ciphertext + contentEnc.nonce + contentEnc.mac),
      title: null,
      content: null,
      encryptionVersion: 1,
    );
  }

  Future<Note> decryptNote(SecretKey noteKey, CryptoService crypto) async {
    if (encryptionVersion == 0) return this;

    final titleCombined = base64Decode(encryptedTitle!);
    final contentCombined = base64Decode(encryptedContent!);

    final titlePayload = _parsePayload(titleCombined);
    final contentPayload = _parsePayload(contentCombined);

    final titleDec = await crypto.decrypt(key: noteKey, payload: titlePayload);
    final contentDec = await crypto.decrypt(key: noteKey, payload: contentPayload);

    return copyWith(
      title: titleDec,
      content: contentDec,
      encryptedTitle: null,
      encryptedContent: null,
      encryptionVersion: 0,
    );
  }

  static EncryptedPayload _parsePayload(Uint8List combined) {
    final ciphertextLen = combined.length - 24;
    return EncryptedPayload(
      ciphertext: combined.sublist(0, ciphertextLen),
      nonce: combined.sublist(ciphertextLen, ciphertextLen + 12),
      mac: combined.sublist(ciphertextLen + 12),
    );
  }

  String get displayTitle {
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
    final combined = (content ?? '').trim().isNotEmpty
        ? (content ?? '').trim()
        : (title ?? '').trim();
    if (combined.isEmpty) {
      return 'Start typing your note here.';
    }

    return combined.replaceAll('\n', ' ').trim();
  }
}
