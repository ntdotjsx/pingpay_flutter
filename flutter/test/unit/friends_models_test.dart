import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/friends/models/friend_models.dart';

void main() {
  group('Feature 2: Friend Models Serialization & Debt Safety Tests', () {
    test('FriendUserModel serializes and deserializes correctly', () {
      final json = {
        'userCode': 'USR-123456',
        'displayName': 'Somchai',
        'avatarUrl': 'https://example.com/avatar.png',
      };

      final model = FriendUserModel.fromJson(json);
      expect(model.userCode, 'USR-123456');
      expect(model.displayName, 'Somchai');
      expect(model.avatarUrl, 'https://example.com/avatar.png');

      final serialized = model.toJson();
      expect(serialized['userCode'], 'USR-123456');
      expect(serialized['displayName'], 'Somchai');
    });

    test('FriendItemModel parses friends since timestamp and user data', () {
      final json = {
        'friendshipId': 'f-999',
        'friendsSince': '2026-08-18T10:00:00.000Z',
        'user': {
          'userCode': 'USR-789',
          'displayName': 'Jane Doe',
          'avatarUrl': null,
        },
      };

      final friend = FriendItemModel.fromJson(json);
      expect(friend.friendshipId, 'f-999');
      expect(friend.user.displayName, 'Jane Doe');
      expect(friend.friendsSince.year, 2026);
    });

    test('FriendRequestItemModel parses incoming/outgoing request', () {
      final json = {
        'requestId': 'req-111',
        'createdAt': '2026-08-18T12:00:00.000Z',
        'user': {'userCode': 'USR-444', 'displayName': 'Bob'},
      };

      final req = FriendRequestItemModel.fromJson(json);
      expect(req.requestId, 'req-111');
      expect(req.user.userCode, 'USR-444');
    });

    test('RelationshipState parses exact backend states', () {
      expect(RelationshipState.fromString('SELF'), RelationshipState.self);
      expect(RelationshipState.fromString('FRIEND'), RelationshipState.friend);
      expect(
        RelationshipState.fromString('OUTGOING_REQUEST'),
        RelationshipState.outgoingRequest,
      );
      expect(
        RelationshipState.fromString('INCOMING_REQUEST'),
        RelationshipState.incomingRequest,
      );
      expect(
        RelationshipState.fromString('BLOCKED'),
        RelationshipState.blocked,
      );
      expect(RelationshipState.fromString('NONE'), RelationshipState.none);
      expect(RelationshipState.fromString('unknown'), RelationshipState.none);
    });

    test(
      'RemovalCheckModel correctly parses zero debt vs outstanding debt',
      () {
        // Case 1: Zero debt
        final zeroDebtJson = {
          'hasOutstandingDebt': false,
          'requiresExplicitDebtConfirmation': false,
        };

        final zeroCheck = RemovalCheckModel.fromJson(zeroDebtJson);
        expect(zeroCheck.hasOutstandingDebt, false);
        expect(zeroCheck.requiresExplicitDebtConfirmation, false);
        expect(zeroCheck.outstanding, isNull);

        // Case 2: Outstanding debt exists
        final activeDebtJson = {
          'hasOutstandingDebt': true,
          'requiresExplicitDebtConfirmation': true,
          'outstanding': {'youOweFriend': '250.00', 'friendOwesYou': '500.00'},
          'warning': {
            'code': 'OUTSTANDING_DEBT_EXISTS',
            'message': 'There is still outstanding debt between these users.',
          },
        };

        final debtCheck = RemovalCheckModel.fromJson(activeDebtJson);
        expect(debtCheck.hasOutstandingDebt, true);
        expect(debtCheck.requiresExplicitDebtConfirmation, true);
        expect(debtCheck.outstanding?.youOweFriend, '250.00');
        expect(debtCheck.outstanding?.friendOwesYou, '500.00');
        expect(
          debtCheck.warningMessage,
          contains('There is still outstanding debt'),
        );
      },
    );
  });
}
