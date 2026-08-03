import 'package:cloud_firestore/cloud_firestore.dart';

/// A moderation report for a comment. Written by any authenticated user,
/// readable by the reporter and the note owner, actioned by support.
class ContentReport {
  final String id;
  final String targetOwnerUid;
  final String noteId;
  final String commentId;
  final String commentAuthorUid;
  final String reporterUid;
  final String reason;
  final String status;
  final DateTime createdAt;

  const ContentReport({
    required this.id,
    required this.targetOwnerUid,
    required this.noteId,
    required this.commentId,
    required this.commentAuthorUid,
    required this.reporterUid,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory ContentReport.create({
    required String targetOwnerUid,
    required String noteId,
    required String commentId,
    required String commentAuthorUid,
    required String reporterUid,
    required String reason,
  }) {
    return ContentReport(
      id: '',
      targetOwnerUid: targetOwnerUid,
      noteId: noteId,
      commentId: commentId,
      commentAuthorUid: commentAuthorUid,
      reporterUid: reporterUid,
      reason: reason,
      status: 'open',
      createdAt: DateTime.now(),
    );
  }

  factory ContentReport.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return ContentReport.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory ContentReport.fromMap(String id, Map<String, dynamic> data) {
    return ContentReport(
      id: id,
      targetOwnerUid: data['targetOwnerUid'] as String? ?? '',
      noteId: data['noteId'] as String? ?? '',
      commentId: data['commentId'] as String? ?? '',
      commentAuthorUid: data['commentAuthorUid'] as String? ?? '',
      reporterUid: data['reporterUid'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetOwnerUid': targetOwnerUid,
      'noteId': noteId,
      'commentId': commentId,
      'commentAuthorUid': commentAuthorUid,
      'reporterUid': reporterUid,
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
