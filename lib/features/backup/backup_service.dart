import 'dart:convert';

import 'package:mynotes/core/encryption/crypto_service.dart';
import 'package:mynotes/features/notes/data/note.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

/// One note as stored in a backup file (after decryption).
class BackupNote {
  final String title;
  final String content;
  final List<String> tags;
  final int colorIndex;
  final bool isPinned;
  final bool isArchived;
  final bool isStudyMaterial;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;
  final String? placeName;
  final DateTime? reminderAt;

  const BackupNote({
    required this.title,
    required this.content,
    this.tags = const [],
    this.colorIndex = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.isStudyMaterial = false,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.placeName,
    this.reminderAt,
  });

  factory BackupNote.fromNote(Note note) => BackupNote(
        title: note.title ?? '',
        content: note.content ?? '',
        tags: note.tags ?? const [],
        colorIndex: note.colorIndex,
        isPinned: note.isPinned,
        isArchived: note.isArchived,
        isStudyMaterial: note.isStudyMaterial,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        latitude: note.latitude,
        longitude: note.longitude,
        placeName: note.placeName,
        reminderAt: note.reminderAt,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'tags': tags,
        'colorIndex': colorIndex,
        'isPinned': isPinned,
        'isArchived': isArchived,
        'isStudyMaterial': isStudyMaterial,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (placeName != null) 'placeName': placeName,
        if (reminderAt != null) 'reminderAt': reminderAt!.toUtc().toIso8601String(),
      };

  factory BackupNote.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final now = DateTime.now();
    return BackupNote(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isStudyMaterial: json['isStudyMaterial'] as bool? ?? false,
      createdAt: date(json['createdAt']) ?? now,
      updatedAt: date(json['updatedAt']) ?? now,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeName: json['placeName'] as String?,
      reminderAt: date(json['reminderAt']),
    );
  }
}

/// Password-encrypted export and import of notes.
///
/// File format (JSON): the notes are serialized, then sealed with
/// AES-256-GCM under a key derived from the backup password with
/// PBKDF2-HMAC-SHA256. The header is authenticated as associated data, so it
/// cannot be swapped. Nothing in the file is readable without the password.
class BackupService {
  BackupService({required this.crypto, this.iterations = 210000});

  final CryptoService crypto;
  final int iterations;

  static const format = 'notely-backup';
  static const version = 1;
  static const minPasswordLength = 8;
  static const fileExtension = 'notely';

  static String _aad(int iterations, String salt) => '$format:v$version:pbkdf2-sha256:$iterations:$salt';

  /// Notes that can go into a backup: decrypted, not trashed, not expired.
  /// PIN-locked notes stay sealed until opened, so they are left out.
  static List<Note> exportable(Iterable<Note> notes) => notes
      .where((n) => !n.isTrashed && !n.isExpired && !n.decryptionFailed && !n.isSealed && n.sharedBy == null)
      .toList();

  Future<String> encode(List<Note> notes, String password, {DateTime? now}) async {
    if (password.length < minPasswordLength) {
      throw const BackupException('Use a password of at least $minPasswordLength characters.');
    }
    final salt = base64Encode(crypto.generateSalt());
    final key = await crypto.deriveKey(password: password, salt: base64Decode(salt), iterations: iterations);
    final payload = jsonEncode({
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'notes': [for (final note in notes) BackupNote.fromNote(note).toJson()],
    });
    final sealed = await crypto.seal(key: key, data: utf8.encode(payload), aad: _aad(iterations, salt));
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'kdf': {'name': 'pbkdf2-sha256', 'iterations': iterations, 'salt': salt},
      'cipher': 'aes-256-gcm',
      'count': notes.length,
      'data': sealed,
    });
  }

  Future<List<BackupNote>> decode(String file, String password) async {
    final Map<String, dynamic> header;
    try {
      header = jsonDecode(file) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException("This isn't a Notely backup file.");
    }
    if (header['format'] != format) throw const BackupException("This isn't a Notely backup file.");
    if ((header['version'] as num?)?.toInt() != version) {
      throw const BackupException('This backup was made by a newer version of Notely. Update the app first.');
    }
    final kdf = header['kdf'] as Map<String, dynamic>? ?? const {};
    final iterations = (kdf['iterations'] as num?)?.toInt() ?? 0;
    final salt = kdf['salt'] as String? ?? '';
    final data = header['data'] as String? ?? '';
    if (iterations <= 0 || salt.isEmpty || data.isEmpty) throw const BackupException('This backup file is damaged.');

    final List<int> plain;
    try {
      final key = await crypto.deriveKey(password: password, salt: base64Decode(salt), iterations: iterations);
      plain = await crypto.open(key: key, sealed: data, aad: _aad(iterations, salt));
    } catch (_) {
      throw const BackupException('Wrong password, or the file is damaged.');
    }
    final body = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return [
      for (final item in body['notes'] as List? ?? const [])
        BackupNote.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  /// File name for an export made on [date], e.g. notely-backup-2026-11-03.notely
  static String fileName(DateTime date) =>
      'notely-backup-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.$fileExtension';
}
