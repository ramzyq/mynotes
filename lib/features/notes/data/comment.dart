import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mynotes/core/encryption/crypto_service.dart';

/// A comment on a note. The body is encrypted with the note key (so only the
/// owner and collaborators can read it) and bound to its note and id via AAD.
class Comment {
  final String id;
  final String authorUid;
  final String authorName;

  /// Decrypted body; null while sealed.
  final String? content;
  final String? encryptedContent;

  /// Generation of the note key the body was encrypted with.
  final int keyGen;
  final DateTime createdAt;
  final bool decryptionFailed;

  const Comment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.content,
    this.encryptedContent,
    this.keyGen = 1,
    required this.createdAt,
    this.decryptionFailed = false,
  });

  /// Text to display, never null.
  String get displayContent {
    if (decryptionFailed) return "Can't decrypt this comment.";
    return content ?? '';
  }

  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final encrypted = data['encryptedContent'] as String?;
    return Comment(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      // Legacy comments were stored in plaintext.
      content: encrypted == null ? data['content'] as String? ?? '' : null,
      encryptedContent: encrypted,
      keyGen: (data['keyGen'] as num?)?.toInt() ?? 1,
      createdAt: _timestampToDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _timestampToDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String aad(String noteId, String commentId) => 'notely:v2:$noteId:comment:$commentId';

  /// Firestore fields for a new comment, with the body encrypted.
  static Future<Map<String, dynamic>> encryptedMap({
    required String noteId,
    required String commentId,
    required String authorUid,
    required String authorName,
    required String content,
    required SecretKey noteKey,
    required int keyGen,
    required CryptoService crypto,
    DateTime? createdAt,
  }) async {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'encryptedContent': await crypto.seal(
        key: noteKey,
        data: utf8.encode(content),
        aad: aad(noteId, commentId),
      ),
      'keyGen': keyGen,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  Future<Comment> decrypt(String noteId, SecretKey key, CryptoService crypto) async {
    if (encryptedContent == null) return this;
    final bytes = await crypto.open(key: key, sealed: encryptedContent!, aad: aad(noteId, id));
    return Comment(
      id: id,
      authorUid: authorUid,
      authorName: authorName,
      content: utf8.decode(bytes),
      keyGen: keyGen,
      createdAt: createdAt,
    );
  }

  Comment asUndecryptable() => Comment(
        id: id,
        authorUid: authorUid,
        authorName: authorName,
        encryptedContent: encryptedContent,
        keyGen: keyGen,
        createdAt: createdAt,
        decryptionFailed: true,
      );
}
