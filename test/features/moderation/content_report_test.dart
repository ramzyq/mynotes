import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/moderation/models/content_report.dart';

void main() {
  test('toMap contains all report fields', () {
    final report = ContentReport.create(
      targetOwnerUid: 'owner',
      noteId: 'note-1',
      commentId: 'comment-1',
      commentAuthorUid: 'author',
      reporterUid: 'reporter',
      reason: 'Harassment',
    );

    final map = report.toMap();
    expect(map['targetOwnerUid'], 'owner');
    expect(map['noteId'], 'note-1');
    expect(map['commentId'], 'comment-1');
    expect(map['commentAuthorUid'], 'author');
    expect(map['reporterUid'], 'reporter');
    expect(map['reason'], 'Harassment');
    expect(map['status'], 'open');
    expect(map['createdAt'], isA<Timestamp>());
  });

  test('fromMap round-trips a stored report', () {
    final report = ContentReport.fromMap('report-1', {
      'targetOwnerUid': 'owner',
      'noteId': 'note-1',
      'commentId': 'comment-1',
      'commentAuthorUid': 'author',
      'reporterUid': 'reporter',
      'reason': 'Spam',
      'status': 'open',
      'createdAt': Timestamp.fromDate(DateTime(2026, 8, 3)),
    });
    expect(report.id, 'report-1');
    expect(report.targetOwnerUid, 'owner');
    expect(report.commentId, 'comment-1');
    expect(report.reason, 'Spam');
    expect(report.status, 'open');
    expect(report.createdAt, DateTime(2026, 8, 3));
  });
}
