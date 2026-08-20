import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/core/theme/theme.dart';
import 'package:pingpay_mobile/features/friends/models/friend_models.dart';
import 'package:pingpay_mobile/features/friends/providers/friends_provider.dart';
import 'package:pingpay_mobile/features/friends/screens/friends_screen.dart';
import 'package:pingpay_mobile/features/friends/screens/add_friend_screen.dart';

void main() {
  group('Feature 2: Friends Widget & Flow Tests', () {
    testWidgets(
      'FriendsScreen renders tabs and empty state when no friends exist',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              friendsListProvider.overrideWith((ref) async => []),
              incomingFriendRequestsProvider.overrideWith((ref) async => []),
              outgoingFriendRequestsProvider.overrideWith((ref) async => []),
            ],
            child: MaterialApp(
              theme: LightTheme.theme,
              home: const FriendsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check header and tabs
        expect(find.text('เพื่อน (Friends)'), findsOneWidget);
        expect(find.text('เพื่อนของฉัน'), findsOneWidget);
        expect(find.text('คำขอเข้า'), findsOneWidget);
        expect(find.text('คำขอที่ส่ง'), findsOneWidget);

        // Check empty state
        expect(find.text('ยังไม่มีเพื่อนในระบบ'), findsOneWidget);
        expect(find.text('+ เพิ่มเพื่อนทันที'), findsOneWidget);
      },
    );

    testWidgets('FriendsScreen renders friend list with items', (tester) async {
      final mockFriends = [
        FriendItemModel(
          friendshipId: 'f1',
          friendsSince: DateTime(2026, 1, 1),
          user: const FriendUserModel(
            userCode: 'USR-111',
            displayName: 'Somchai Demo',
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            friendsListProvider.overrideWith((ref) async => mockFriends),
            incomingFriendRequestsProvider.overrideWith((ref) async => []),
            outgoingFriendRequestsProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            theme: LightTheme.theme,
            home: const FriendsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Somchai Demo'), findsOneWidget);
      expect(find.text('รหัส: USR-111'), findsOneWidget);
    });

    testWidgets(
      'AddFriendScreen renders search input and validation elements',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: LightTheme.theme,
              home: const AddFriendScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('เพิ่มเพื่อนใหม่'), findsOneWidget);
        expect(
          find.text('ค้นหาด้วยรหัสประจำตัว (User Code / ID)'),
          findsOneWidget,
        );
        expect(find.text('ค้นหา'), findsOneWidget);
      },
    );
  });
}
