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
      expect(buildJoinUrl('abc123'), 'https://${appConfig.shareDomain}/join/abc123');
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
